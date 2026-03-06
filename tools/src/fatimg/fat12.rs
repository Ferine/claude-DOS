use super::bpb::BiosParameterBlock;
use std::collections::HashMap;

/// FAT12 disk image builder
pub struct Fat12Image {
    pub bpb: BiosParameterBlock,
    pub data: Vec<u8>,
    next_cluster: u16,
    /// Maps directory paths to their starting cluster (e.g., "DATOS" -> 5)
    directories: HashMap<String, u16>,
}

impl Fat12Image {
    /// Create a new blank FAT12 1.44MB floppy image
    pub fn new() -> Self {
        let bpb = BiosParameterBlock::floppy_1440();
        let total_bytes = bpb.total_sectors_16 as usize * bpb.bytes_per_sector as usize;
        let mut data = vec![0u8; total_bytes];

        // Initialize both FATs with media descriptor
        let fat_start = bpb.reserved_sectors as usize * bpb.bytes_per_sector as usize;
        let fat_size = bpb.fat_size_16 as usize * bpb.bytes_per_sector as usize;

        for i in 0..bpb.num_fats as usize {
            let offset = fat_start + i * fat_size;
            // FAT12: first two entries are reserved
            // Entry 0: media descriptor | 0xF00
            // Entry 1: 0xFFF (end of chain marker)
            // Bytes: F0 FF FF
            data[offset] = bpb.media_type;
            data[offset + 1] = 0xFF;
            data[offset + 2] = 0xFF;
        }

        Self {
            bpb,
            data,
            next_cluster: 2, // First usable cluster
            directories: HashMap::new(),
        }
    }

    /// Write the VBR (boot sector) from assembled binary
    pub fn write_boot_sector(&mut self, vbr: &[u8]) {
        assert!(vbr.len() == 512, "VBR must be exactly 512 bytes");
        // Copy VBR but preserve the BPB area (bytes 0-2 jump + 3-10 OEM = keep from VBR,
        // 11-61 BPB = keep from VBR since it should match, 62+ boot code from VBR)
        self.data[..512].copy_from_slice(vbr);
    }

    /// Add a file to the root directory and write its data to the data area.
    /// The filename must be in 8.3 format (11 bytes, space-padded).
    /// Returns the starting cluster number.
    pub fn add_file(&mut self, name_8_3: &[u8; 11], contents: &[u8]) -> u16 {
        let start_cluster = self.next_cluster;
        let bytes_per_cluster =
            self.bpb.sectors_per_cluster as usize * self.bpb.bytes_per_sector as usize;
        let clusters_needed = if contents.is_empty() {
            1
        } else {
            (contents.len() + bytes_per_cluster - 1) / bytes_per_cluster
        };

        // Write file data to data area
        for i in 0..clusters_needed {
            let cluster = start_cluster + i as u16;
            let data_offset = self.cluster_to_offset(cluster);
            let src_start = i * bytes_per_cluster;
            let src_end = std::cmp::min(src_start + bytes_per_cluster, contents.len());
            if src_start < contents.len() {
                self.data[data_offset..data_offset + (src_end - src_start)]
                    .copy_from_slice(&contents[src_start..src_end]);
            }

            // Update FAT entries
            let next = if i + 1 < clusters_needed {
                cluster + 1 // Next cluster in chain
            } else {
                0x0FFF // End of chain
            };
            self.set_fat12_entry(cluster, next);
        }

        self.next_cluster += clusters_needed as u16;

        // Add directory entry to root directory
        self.add_root_dir_entry(name_8_3, start_cluster, contents.len() as u32);

        start_cluster
    }

    /// Convert cluster number to byte offset in image
    fn cluster_to_offset(&self, cluster: u16) -> usize {
        let sector = self.bpb.data_start_sector() as usize
            + (cluster as usize - 2) * self.bpb.sectors_per_cluster as usize;
        sector * self.bpb.bytes_per_sector as usize
    }

    /// Set a FAT12 entry
    fn set_fat12_entry(&mut self, cluster: u16, value: u16) {
        let fat_start = self.bpb.reserved_sectors as usize * self.bpb.bytes_per_sector as usize;
        let fat_size = self.bpb.fat_size_16 as usize * self.bpb.bytes_per_sector as usize;

        // Calculate byte offset: cluster * 3 / 2
        let offset = (cluster as usize * 3) / 2;

        for fat_idx in 0..self.bpb.num_fats as usize {
            let base = fat_start + fat_idx * fat_size + offset;
            let word = u16::from_le_bytes([self.data[base], self.data[base + 1]]);

            let new_word = if cluster % 2 == 0 {
                // Even: low 12 bits
                (word & 0xF000) | (value & 0x0FFF)
            } else {
                // Odd: high 12 bits
                (word & 0x000F) | ((value & 0x0FFF) << 4)
            };

            let bytes = new_word.to_le_bytes();
            self.data[base] = bytes[0];
            self.data[base + 1] = bytes[1];
        }
    }

    /// Add a directory entry to the root directory
    fn add_root_dir_entry(&mut self, name: &[u8; 11], start_cluster: u16, file_size: u32) {
        self.add_root_dir_entry_with_attr(name, start_cluster, file_size, 0x20)
    }

    /// Add a directory entry to the root directory with custom attribute
    fn add_root_dir_entry_with_attr(
        &mut self,
        name: &[u8; 11],
        start_cluster: u16,
        file_size: u32,
        attr: u8,
    ) {
        let root_start =
            self.bpb.root_dir_start_sector() as usize * self.bpb.bytes_per_sector as usize;
        let max_entries = self.bpb.root_entry_count as usize;

        // Find first free entry
        for i in 0..max_entries {
            let offset = root_start + i * 32;
            if self.data[offset] == 0x00 || self.data[offset] == 0xE5 {
                self.write_dir_entry(offset, name, start_cluster, file_size, attr);
                return;
            }
        }
        panic!("Root directory is full");
    }

    /// Create a subdirectory in the root directory.
    /// Returns the starting cluster of the new directory.
    pub fn create_directory(&mut self, name_8_3: &[u8; 11], parent_cluster: u16) -> u16 {
        let name_str = String::from_utf8_lossy(name_8_3).trim().to_string();
        let dir_key = Self::directory_key(parent_cluster, &name_str);

        // Check if already created
        if let Some(&cluster) = self.directories.get(&dir_key) {
            return cluster;
        }

        // Allocate a cluster for the directory
        let dir_cluster = self.next_cluster;
        self.next_cluster += 1;

        // Mark cluster as end of chain
        self.set_fat12_entry(dir_cluster, 0x0FFF);

        // Initialize directory cluster with . and .. entries
        let dir_offset = self.cluster_to_offset(dir_cluster);

        // Clear the cluster first
        let bytes_per_cluster =
            self.bpb.sectors_per_cluster as usize * self.bpb.bytes_per_sector as usize;
        for i in 0..bytes_per_cluster {
            self.data[dir_offset + i] = 0;
        }

        // Create "." entry (self)
        let dot_name: [u8; 11] = *b".          ";
        self.data[dir_offset..dir_offset + 11].copy_from_slice(&dot_name);
        self.data[dir_offset + 11] = 0x10; // Directory attribute
        let cluster_bytes = dir_cluster.to_le_bytes();
        self.data[dir_offset + 26] = cluster_bytes[0];
        self.data[dir_offset + 27] = cluster_bytes[1];

        // Create ".." entry (parent = root, cluster 0)
        let dotdot_name: [u8; 11] = *b"..         ";
        self.data[dir_offset + 32..dir_offset + 43].copy_from_slice(&dotdot_name);
        self.data[dir_offset + 32 + 11] = 0x10; // Directory attribute
        let parent_bytes = parent_cluster.to_le_bytes();
        self.data[dir_offset + 32 + 26] = parent_bytes[0];
        self.data[dir_offset + 32 + 27] = parent_bytes[1];

        if parent_cluster == 0 {
            self.add_root_dir_entry_with_attr(name_8_3, dir_cluster, 0, 0x10);
        } else {
            self.add_subdir_entry_with_attr(parent_cluster, name_8_3, dir_cluster, 0, 0x10);
        }

        // Remember this directory
        self.directories.insert(dir_key, dir_cluster);

        dir_cluster
    }

    /// Add a file to a subdirectory.
    /// Returns the starting cluster number of the file.
    pub fn add_file_to_directory(
        &mut self,
        dir_cluster: u16,
        name_8_3: &[u8; 11],
        contents: &[u8],
    ) -> u16 {
        let start_cluster = self.next_cluster;
        let bytes_per_cluster =
            self.bpb.sectors_per_cluster as usize * self.bpb.bytes_per_sector as usize;
        let clusters_needed = if contents.is_empty() {
            1
        } else {
            (contents.len() + bytes_per_cluster - 1) / bytes_per_cluster
        };

        // Write file data to data area
        for i in 0..clusters_needed {
            let cluster = start_cluster + i as u16;
            let data_offset = self.cluster_to_offset(cluster);
            let src_start = i * bytes_per_cluster;
            let src_end = std::cmp::min(src_start + bytes_per_cluster, contents.len());
            if src_start < contents.len() {
                self.data[data_offset..data_offset + (src_end - src_start)]
                    .copy_from_slice(&contents[src_start..src_end]);
            }

            // Update FAT entries
            let next = if i + 1 < clusters_needed {
                cluster + 1 // Next cluster in chain
            } else {
                0x0FFF // End of chain
            };
            self.set_fat12_entry(cluster, next);
        }

        self.next_cluster += clusters_needed as u16;

        // Add directory entry to the subdirectory
        self.add_subdir_entry(dir_cluster, name_8_3, start_cluster, contents.len() as u32);

        start_cluster
    }

    /// Add a directory entry to a subdirectory (supports multi-cluster directories)
    fn add_subdir_entry(
        &mut self,
        dir_cluster: u16,
        name: &[u8; 11],
        start_cluster: u16,
        file_size: u32,
    ) {
        self.add_subdir_entry_with_attr(dir_cluster, name, start_cluster, file_size, 0x20);
    }

    fn add_subdir_entry_with_attr(
        &mut self,
        dir_cluster: u16,
        name: &[u8; 11],
        start_cluster: u16,
        file_size: u32,
        attr: u8,
    ) {
        let bytes_per_cluster =
            self.bpb.sectors_per_cluster as usize * self.bpb.bytes_per_sector as usize;
        let max_entries_per_cluster = bytes_per_cluster / 32;

        // Walk the cluster chain to find a free entry
        let mut current_cluster = dir_cluster;
        loop {
            let dir_offset = self.cluster_to_offset(current_cluster);

            // Find first free entry in this cluster
            for i in 0..max_entries_per_cluster {
                let offset = dir_offset + i * 32;
                if self.data[offset] == 0x00 || self.data[offset] == 0xE5 {
                    self.write_dir_entry(offset, name, start_cluster, file_size, attr);
                    return;
                }
            }

            // This cluster is full, check for next cluster in chain
            let next_cluster = self.get_fat12_entry(current_cluster);
            if next_cluster >= 0x0FF8 {
                // End of chain, need to extend the directory
                let new_cluster = self.next_cluster;
                self.next_cluster += 1;

                // Link the new cluster
                self.set_fat12_entry(current_cluster, new_cluster);
                self.set_fat12_entry(new_cluster, 0x0FFF);

                // Clear the new cluster
                let new_offset = self.cluster_to_offset(new_cluster);
                for j in 0..bytes_per_cluster {
                    self.data[new_offset + j] = 0;
                }

                current_cluster = new_cluster;
            } else {
                current_cluster = next_cluster;
            }
        }
    }

    fn write_dir_entry(
        &mut self,
        offset: usize,
        name: &[u8; 11],
        start_cluster: u16,
        file_size: u32,
        attr: u8,
    ) {
        self.data[offset..offset + 11].copy_from_slice(name);
        self.data[offset + 11] = attr;
        let cluster_bytes = start_cluster.to_le_bytes();
        self.data[offset + 26] = cluster_bytes[0];
        self.data[offset + 27] = cluster_bytes[1];
        let size_bytes = file_size.to_le_bytes();
        self.data[offset + 28..offset + 32].copy_from_slice(&size_bytes);
    }

    /// Get a FAT12 entry value
    fn get_fat12_entry(&self, cluster: u16) -> u16 {
        let fat_start = self.bpb.reserved_sectors as usize * self.bpb.bytes_per_sector as usize;
        let offset = (cluster as usize * 3) / 2;
        let base = fat_start + offset;
        let word = u16::from_le_bytes([self.data[base], self.data[base + 1]]);

        if cluster % 2 == 0 {
            word & 0x0FFF
        } else {
            word >> 4
        }
    }

    /// Add a file with a path (e.g., "DATOS/FILE.FLI").
    /// Creates directories as needed. Returns the starting cluster.
    pub fn add_file_with_path(&mut self, path: &str, name_8_3: &[u8; 11], contents: &[u8]) -> u16 {
        // Split path into components
        let parts: Vec<&str> = path.split('/').collect();

        if parts.len() == 1 {
            // No subdirectory, add to root
            return self.add_file(name_8_3, contents);
        }

        // Create directories for all but the last component
        let mut current_cluster = 0u16; // Start at root
        for (i, part) in parts.iter().enumerate() {
            if i == parts.len() - 1 {
                // This is the filename - skip it
                break;
            }
            if part.is_empty() {
                continue;
            }

            // Convert to 8.3 name
            let dir_name = to_fat_name_internal(part);
            let dir_key =
                Self::directory_key(current_cluster, String::from_utf8_lossy(&dir_name).trim());

            // Check if directory already exists
            if let Some(&cluster) = self.directories.get(&dir_key) {
                current_cluster = cluster;
            } else {
                // Create the directory
                current_cluster = self.create_directory(&dir_name, current_cluster);
            }
        }

        // Add file to the directory
        if current_cluster == 0 {
            self.add_file(name_8_3, contents)
        } else {
            self.add_file_to_directory(current_cluster, name_8_3, contents)
        }
    }

    /// Get the cluster for a directory path, or None if it doesn't exist
    pub fn get_directory_cluster(&self, path: &str) -> Option<u16> {
        let mut current_cluster = 0u16;
        for part in path.split('/') {
            let normalized = part.trim().to_uppercase();
            if normalized.is_empty() {
                continue;
            }
            let key = Self::directory_key(current_cluster, &normalized);
            current_cluster = self.directories.get(&key).copied()?;
        }
        Some(current_cluster)
    }

    /// Get the raw image data
    pub fn as_bytes(&self) -> &[u8] {
        &self.data
    }

    fn directory_key(parent_cluster: u16, name: &str) -> String {
        if parent_cluster == 0 {
            name.to_string()
        } else {
            format!("{}:{}", parent_cluster, name)
        }
    }
}

/// Convert a DOS-style filename to 8.3 space-padded format (internal helper)
fn to_fat_name_internal(name: &str) -> [u8; 11] {
    let mut result = [b' '; 11];
    let upper = name.to_uppercase();

    if let Some(dot_pos) = upper.find('.') {
        let (base, ext) = upper.split_at(dot_pos);
        let ext = &ext[1..]; // skip the dot
        for (i, b) in base.bytes().take(8).enumerate() {
            result[i] = b;
        }
        for (i, b) in ext.bytes().take(3).enumerate() {
            result[8 + i] = b;
        }
    } else {
        for (i, b) in upper.bytes().take(8).enumerate() {
            result[i] = b;
        }
    }
    result
}

#[cfg(test)]
mod tests {
    use super::*;

    fn entry_names_in_root(img: &Fat12Image) -> Vec<[u8; 11]> {
        let root_start =
            img.bpb.root_dir_start_sector() as usize * img.bpb.bytes_per_sector as usize;
        let max_entries = img.bpb.root_entry_count as usize;
        let mut names = Vec::new();

        for i in 0..max_entries {
            let offset = root_start + i * 32;
            let first_byte = img.data[offset];
            if first_byte == 0x00 {
                break;
            }
            if first_byte == 0xE5 {
                continue;
            }
            let mut name = [0u8; 11];
            name.copy_from_slice(&img.data[offset..offset + 11]);
            names.push(name);
        }

        names
    }

    fn entry_names_in_subdir(img: &Fat12Image, cluster: u16) -> Vec<[u8; 11]> {
        let dir_offset = img.cluster_to_offset(cluster);
        let bytes_per_cluster =
            img.bpb.sectors_per_cluster as usize * img.bpb.bytes_per_sector as usize;
        let max_entries = bytes_per_cluster / 32;
        let mut names = Vec::new();

        for i in 0..max_entries {
            let offset = dir_offset + i * 32;
            let first_byte = img.data[offset];
            if first_byte == 0x00 {
                break;
            }
            if first_byte == 0xE5 {
                continue;
            }
            let mut name = [0u8; 11];
            name.copy_from_slice(&img.data[offset..offset + 11]);
            names.push(name);
        }

        names
    }

    #[test]
    fn nested_directory_is_attached_to_parent() {
        let mut img = Fat12Image::new();
        let file_name = to_fat_name_internal("FILE.TXT");

        img.add_file_with_path("FOO/BAR/FILE.TXT", &file_name, b"test");

        let foo_cluster = img.get_directory_cluster("FOO").expect("FOO directory");
        let bar_cluster = img
            .get_directory_cluster("FOO/BAR")
            .expect("FOO/BAR directory");

        let root_names = entry_names_in_root(&img);
        assert!(root_names.contains(&to_fat_name_internal("FOO")));
        assert!(!root_names.contains(&to_fat_name_internal("BAR")));

        let foo_names = entry_names_in_subdir(&img, foo_cluster);
        assert!(foo_names.contains(&to_fat_name_internal("BAR")));

        let bar_offset = img.cluster_to_offset(bar_cluster);
        let parent = u16::from_le_bytes([
            img.data[bar_offset + 32 + 26],
            img.data[bar_offset + 32 + 27],
        ]);
        assert_eq!(parent, foo_cluster);
    }

    #[test]
    fn same_directory_name_under_different_parents_does_not_collide() {
        let mut img = Fat12Image::new();
        let one = to_fat_name_internal("ONE.TXT");
        let two = to_fat_name_internal("TWO.TXT");

        img.add_file_with_path("A/COMMON/ONE.TXT", &one, b"one");
        img.add_file_with_path("B/COMMON/TWO.TXT", &two, b"two");

        let a_common = img
            .get_directory_cluster("A/COMMON")
            .expect("A/COMMON directory");
        let b_common = img
            .get_directory_cluster("B/COMMON")
            .expect("B/COMMON directory");

        assert_ne!(a_common, b_common);
    }
}
