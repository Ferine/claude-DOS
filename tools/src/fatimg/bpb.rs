/// BIOS Parameter Block for FAT12 1.44MB floppy
#[derive(Debug, Clone)]
pub struct BiosParameterBlock {
    pub bytes_per_sector: u16,
    pub sectors_per_cluster: u8,
    pub reserved_sectors: u16,
    pub num_fats: u8,
    pub root_entry_count: u16,
    pub total_sectors_16: u16,
    pub media_type: u8,
    pub fat_size_16: u16,
    pub sectors_per_track: u16,
    pub num_heads: u16,
    pub hidden_sectors: u32,
    pub total_sectors_32: u32,
    // Extended BPB
    pub drive_number: u8,
    pub boot_signature: u8,
    pub volume_id: u32,
    pub volume_label: [u8; 11],
    pub fs_type: [u8; 8],
}

impl BiosParameterBlock {
    /// Standard 1.44MB 3.5" floppy BPB
    pub fn floppy_1440() -> Self {
        Self {
            bytes_per_sector: 512,
            sectors_per_cluster: 1,
            reserved_sectors: 1,
            num_fats: 2,
            root_entry_count: 224,
            total_sectors_16: 2880,
            media_type: 0xF0,
            fat_size_16: 9,
            sectors_per_track: 18,
            num_heads: 2,
            hidden_sectors: 0,
            total_sectors_32: 0,
            drive_number: 0x00,
            boot_signature: 0x29,
            volume_id: 0x434C444F,
            volume_label: *b"CLAUDEDOS  ",
            fs_type: *b"FAT12   ",
        }
    }

    pub fn root_dir_start_sector(&self) -> u16 {
        self.reserved_sectors + (self.num_fats as u16) * self.fat_size_16
    }

    pub fn root_dir_sectors(&self) -> u16 {
        ((self.root_entry_count as u32 * 32 + self.bytes_per_sector as u32 - 1)
            / self.bytes_per_sector as u32) as u16
    }

    pub fn data_start_sector(&self) -> u16 {
        self.root_dir_start_sector() + self.root_dir_sectors()
    }

    pub fn total_data_clusters(&self) -> u16 {
        (self.total_sectors_16 - self.data_start_sector()) / self.sectors_per_cluster as u16
    }

    /// Serialize BPB to bytes (offset 11..62 in boot sector)
    pub fn to_bytes(&self) -> Vec<u8> {
        let mut buf = Vec::with_capacity(51);
        buf.extend_from_slice(&self.bytes_per_sector.to_le_bytes());
        buf.push(self.sectors_per_cluster);
        buf.extend_from_slice(&self.reserved_sectors.to_le_bytes());
        buf.push(self.num_fats);
        buf.extend_from_slice(&self.root_entry_count.to_le_bytes());
        buf.extend_from_slice(&self.total_sectors_16.to_le_bytes());
        buf.push(self.media_type);
        buf.extend_from_slice(&self.fat_size_16.to_le_bytes());
        buf.extend_from_slice(&self.sectors_per_track.to_le_bytes());
        buf.extend_from_slice(&self.num_heads.to_le_bytes());
        buf.extend_from_slice(&self.hidden_sectors.to_le_bytes());
        buf.extend_from_slice(&self.total_sectors_32.to_le_bytes());
        // Extended BPB
        buf.push(self.drive_number);
        buf.push(0); // reserved
        buf.push(self.boot_signature);
        buf.extend_from_slice(&self.volume_id.to_le_bytes());
        buf.extend_from_slice(&self.volume_label);
        buf.extend_from_slice(&self.fs_type);
        buf
    }
}
