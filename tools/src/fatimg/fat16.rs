use super::bpb::BiosParameterBlock;
use std::collections::HashMap;

/// FAT16 hard disk image builder
pub struct Fat16Image {
    pub bpb: BiosParameterBlock,
    pub data: Vec<u8>,
    next_cluster: u16,
    directories: HashMap<String, u16>,
}

impl Fat16Image {
    /// Create a new blank FAT16 32MB hard disk image
    pub fn new() -> Self {
        let bpb = BiosParameterBlock::hard_disk_32mb();
        let total_bytes = bpb.total_sectors() as usize * bpb.bytes_per_sector as usize;
        let mut data = vec![0u8; total_bytes];

        // Initialize both FATs with media descriptor
        let fat_start = bpb.reserved_sectors as usize * bpb.bytes_per_sector as usize;
        let fat_size = bpb.fat_size_16 as usize * bpb.bytes_per_sector as usize;

        for i in 0..bpb.num_fats as usize {
            let offset = fat_start + i * fat_size;
            // FAT16: first two entries are reserved
            // Entry 0: 0xFFF8 (media descriptor in low byte, 0xFF in high)
            // Entry 1: 0xFFFF (end of chain marker)
            data[offset] = bpb.media_type;  // 0xF8
            data[offset + 1] = 0xFF;
            data[offset + 2] = 0xFF;
            data[offset + 3] = 0xFF;
        }

        Self {
            bpb,
            data,
            next_cluster: 2, // First usable cluster
            directories: HashMap::new(),
        }
    }

    /// Write a dummy boot sector with valid BPB
    pub fn write_boot_sector(&mut self) {
        // Jump instruction (short jump over BPB)
        self.data[0] = 0xEB; // JMP SHORT
        self.data[1] = 0x3C; // offset to boot code
        self.data[2] = 0x90; // NOP

        // OEM name
        self.data[3..11].copy_from_slice(b"CLAUDDOS");

        // BPB at offset 11
        let bpb_bytes = self.bpb.to_bytes();
        self.data[11..11 + bpb_bytes.len()].copy_from_slice(&bpb_bytes);

        // Boot signature at 510-511
        self.data[510] = 0x55;
        self.data[511] = 0xAA;
    }

    /// Add a file to the root directory. Returns starting cluster.
    pub fn add_file(&mut self, name_8_3: &[u8; 11], contents: &[u8]) -> u16 {
        let start_cluster = self.write_file_data(contents);
        self.add_root_dir_entry(name_8_3, start_cluster, contents.len() as u32);
        start_cluster
    }

    /// Add a file with a path (e.g., "ID1/PAK0.PAK"). Returns starting cluster.
    pub fn add_file_with_path(&mut self, path: &str, name_8_3: &[u8; 11], contents: &[u8]) -> u16 {
        let parts: Vec<&str> = path.split('/').collect();

        if parts.len() <= 1 {
            return self.add_file(name_8_3, contents);
        }

        // Create directories for all but the last component
        let mut dir_cluster = 0u16; // 0 = root
        for part in &parts[..parts.len() - 1] {
            if part.is_empty() {
                continue;
            }
            let dir_name = to_fat_dir_name(part);
            let key = if dir_cluster == 0 {
                part.to_uppercase()
            } else {
                format!("{}:{}", dir_cluster, part.to_uppercase())
            };
            if let Some(&c) = self.directories.get(&key) {
                dir_cluster = c;
            } else {
                let c = self.create_directory(&dir_name, dir_cluster);
                self.directories.insert(key, c);
                dir_cluster = c;
            }
        }

        // Add the file to the final directory
        let start_cluster = self.write_file_data(contents);
        self.add_subdir_entry(dir_cluster, name_8_3, start_cluster, contents.len() as u32);
        start_cluster
    }

    /// Write file data to clusters and return starting cluster
    fn write_file_data(&mut self, contents: &[u8]) -> u16 {
        let start_cluster = self.next_cluster;
        let bytes_per_cluster =
            self.bpb.sectors_per_cluster as usize * self.bpb.bytes_per_sector as usize;
        let clusters_needed = if contents.is_empty() {
            1
        } else {
            (contents.len() + bytes_per_cluster - 1) / bytes_per_cluster
        };

        for i in 0..clusters_needed {
            let cluster = start_cluster + i as u16;
            let data_offset = self.cluster_to_offset(cluster);
            let src_start = i * bytes_per_cluster;
            let src_end = std::cmp::min(src_start + bytes_per_cluster, contents.len());
            if src_start < contents.len() {
                self.data[data_offset..data_offset + (src_end - src_start)]
                    .copy_from_slice(&contents[src_start..src_end]);
            }

            let next = if i + 1 < clusters_needed {
                cluster + 1
            } else {
                0xFFFF // End of chain (FAT16)
            };
            self.set_fat16_entry(cluster, next);
        }

        self.next_cluster += clusters_needed as u16;
        start_cluster
    }

    /// Create a subdirectory. parent_cluster=0 means root.
    fn create_directory(&mut self, name_8_3: &[u8; 11], parent_cluster: u16) -> u16 {
        let dir_cluster = self.next_cluster;
        self.next_cluster += 1;

        // Mark cluster as end of chain
        self.set_fat16_entry(dir_cluster, 0xFFFF);

        // Initialize directory cluster with . and .. entries
        let dir_offset = self.cluster_to_offset(dir_cluster);
        let bytes_per_cluster =
            self.bpb.sectors_per_cluster as usize * self.bpb.bytes_per_sector as usize;
        for i in 0..bytes_per_cluster {
            self.data[dir_offset + i] = 0;
        }

        // "." entry
        self.data[dir_offset..dir_offset + 11].copy_from_slice(b".          ");
        self.data[dir_offset + 11] = 0x10;
        let cb = dir_cluster.to_le_bytes();
        self.data[dir_offset + 26] = cb[0];
        self.data[dir_offset + 27] = cb[1];

        // ".." entry
        self.data[dir_offset + 32..dir_offset + 43].copy_from_slice(b"..         ");
        self.data[dir_offset + 32 + 11] = 0x10;
        let pb = parent_cluster.to_le_bytes();
        self.data[dir_offset + 32 + 26] = pb[0];
        self.data[dir_offset + 32 + 27] = pb[1];

        // Add directory entry to parent
        if parent_cluster == 0 {
            self.add_root_dir_entry_with_attr(name_8_3, dir_cluster, 0, 0x10);
        } else {
            self.add_subdir_entry_with_attr(parent_cluster, name_8_3, dir_cluster, 0, 0x10);
        }

        dir_cluster
    }

    /// Convert cluster number to byte offset in image
    fn cluster_to_offset(&self, cluster: u16) -> usize {
        let sector = self.bpb.data_start_sector() as usize
            + (cluster as usize - 2) * self.bpb.sectors_per_cluster as usize;
        sector * self.bpb.bytes_per_sector as usize
    }

    /// Set a FAT16 entry (2 bytes per entry)
    fn set_fat16_entry(&mut self, cluster: u16, value: u16) {
        let fat_start = self.bpb.reserved_sectors as usize * self.bpb.bytes_per_sector as usize;
        let fat_size = self.bpb.fat_size_16 as usize * self.bpb.bytes_per_sector as usize;
        let offset = cluster as usize * 2;

        let bytes = value.to_le_bytes();
        for fat_idx in 0..self.bpb.num_fats as usize {
            let base = fat_start + fat_idx * fat_size + offset;
            self.data[base] = bytes[0];
            self.data[base + 1] = bytes[1];
        }
    }

    /// Get a FAT16 entry value
    fn get_fat16_entry(&self, cluster: u16) -> u16 {
        let fat_start = self.bpb.reserved_sectors as usize * self.bpb.bytes_per_sector as usize;
        let offset = cluster as usize * 2;
        u16::from_le_bytes([self.data[fat_start + offset], self.data[fat_start + offset + 1]])
    }

    /// Add a directory entry to the root directory
    fn add_root_dir_entry(&mut self, name: &[u8; 11], start_cluster: u16, file_size: u32) {
        self.add_root_dir_entry_with_attr(name, start_cluster, file_size, 0x20);
    }

    fn add_root_dir_entry_with_attr(&mut self, name: &[u8; 11], start_cluster: u16, file_size: u32, attr: u8) {
        let root_start =
            self.bpb.root_dir_start_sector() as usize * self.bpb.bytes_per_sector as usize;
        let max_entries = self.bpb.root_entry_count as usize;

        for i in 0..max_entries {
            let offset = root_start + i * 32;
            if self.data[offset] == 0x00 || self.data[offset] == 0xE5 {
                self.write_dir_entry(offset, name, start_cluster, file_size, attr);
                return;
            }
        }
        panic!("Root directory is full");
    }

    /// Add a directory entry to a subdirectory
    fn add_subdir_entry(&mut self, dir_cluster: u16, name: &[u8; 11], start_cluster: u16, file_size: u32) {
        self.add_subdir_entry_with_attr(dir_cluster, name, start_cluster, file_size, 0x20);
    }

    fn add_subdir_entry_with_attr(&mut self, dir_cluster: u16, name: &[u8; 11], start_cluster: u16, file_size: u32, attr: u8) {
        let bytes_per_cluster =
            self.bpb.sectors_per_cluster as usize * self.bpb.bytes_per_sector as usize;
        let max_entries_per_cluster = bytes_per_cluster / 32;

        let mut current_cluster = dir_cluster;
        loop {
            let dir_offset = self.cluster_to_offset(current_cluster);
            for i in 0..max_entries_per_cluster {
                let offset = dir_offset + i * 32;
                if self.data[offset] == 0x00 || self.data[offset] == 0xE5 {
                    self.write_dir_entry(offset, name, start_cluster, file_size, attr);
                    return;
                }
            }

            let next = self.get_fat16_entry(current_cluster);
            if next >= 0xFFF8 {
                // Extend directory
                let new_cluster = self.next_cluster;
                self.next_cluster += 1;
                self.set_fat16_entry(current_cluster, new_cluster);
                self.set_fat16_entry(new_cluster, 0xFFFF);
                let new_offset = self.cluster_to_offset(new_cluster);
                for j in 0..bytes_per_cluster {
                    self.data[new_offset + j] = 0;
                }
                current_cluster = new_cluster;
            } else {
                current_cluster = next;
            }
        }
    }

    /// Write a 32-byte directory entry at the given byte offset
    fn write_dir_entry(&mut self, offset: usize, name: &[u8; 11], start_cluster: u16, file_size: u32, attr: u8) {
        self.data[offset..offset + 11].copy_from_slice(name);
        self.data[offset + 11] = attr;
        let cluster_bytes = start_cluster.to_le_bytes();
        self.data[offset + 26] = cluster_bytes[0];
        self.data[offset + 27] = cluster_bytes[1];
        let size_bytes = file_size.to_le_bytes();
        self.data[offset + 28..offset + 32].copy_from_slice(&size_bytes);
    }

    /// Get the raw image data
    pub fn as_bytes(&self) -> &[u8] {
        &self.data
    }
}

/// Convert a directory name to 8.3 space-padded format (no extension)
fn to_fat_dir_name(name: &str) -> [u8; 11] {
    let mut result = [b' '; 11];
    let upper = name.to_uppercase();
    let bytes = upper.as_bytes();
    let len = std::cmp::min(bytes.len(), 8);
    result[..len].copy_from_slice(&bytes[..len]);
    result
}
