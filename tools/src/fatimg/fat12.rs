use super::bpb::BiosParameterBlock;

/// FAT12 disk image builder
pub struct Fat12Image {
    pub bpb: BiosParameterBlock,
    pub data: Vec<u8>,
    next_cluster: u16,
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
        let sector = self.bpb.data_start_sector() as usize + (cluster as usize - 2)
            * self.bpb.sectors_per_cluster as usize;
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
        let root_start = self.bpb.root_dir_start_sector() as usize
            * self.bpb.bytes_per_sector as usize;
        let max_entries = self.bpb.root_entry_count as usize;

        // Find first free entry
        for i in 0..max_entries {
            let offset = root_start + i * 32;
            if self.data[offset] == 0x00 || self.data[offset] == 0xE5 {
                // Write directory entry
                self.data[offset..offset + 11].copy_from_slice(name);
                self.data[offset + 11] = 0x20; // Archive attribute
                // Bytes 12-25: timestamps etc. (leave as zero for simplicity)
                // Starting cluster at offset 26-27
                let cluster_bytes = start_cluster.to_le_bytes();
                self.data[offset + 26] = cluster_bytes[0];
                self.data[offset + 27] = cluster_bytes[1];
                // File size at offset 28-31
                let size_bytes = file_size.to_le_bytes();
                self.data[offset + 28..offset + 32].copy_from_slice(&size_bytes);
                return;
            }
        }
        panic!("Root directory is full");
    }

    /// Get the raw image data
    pub fn as_bytes(&self) -> &[u8] {
        &self.data
    }
}
