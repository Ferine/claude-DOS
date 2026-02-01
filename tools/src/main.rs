mod fatimg;

use fatimg::fat12::Fat12Image;
use std::fs;
use std::path::PathBuf;

/// Convert a DOS-style filename (e.g. "STAGE2.BIN") to 8.3 space-padded format
fn to_fat_name(name: &str) -> [u8; 11] {
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

fn main() {
    let args: Vec<String> = std::env::args().collect();

    if args.len() < 3 {
        eprintln!("Usage: mkfloppy <output.img> <vbr.bin> [file1:DOSNAME file2:DOSNAME ...]");
        eprintln!("  DOSNAME is a DOS filename like STAGE2.BIN or IO.SYS");
        eprintln!("  Example: mkfloppy floppy.img vbr.bin stage2.bin:STAGE2.BIN io.sys:IO.SYS");
        std::process::exit(1);
    }

    let output_path = PathBuf::from(&args[1]);
    let vbr_path = PathBuf::from(&args[2]);

    let mut img = Fat12Image::new();

    // Write boot sector
    let vbr = fs::read(&vbr_path).unwrap_or_else(|e| {
        eprintln!("Failed to read VBR '{}': {}", vbr_path.display(), e);
        std::process::exit(1);
    });
    img.write_boot_sector(&vbr);

    // Add files
    for arg in &args[3..] {
        let parts: Vec<&str> = arg.splitn(2, ':').collect();
        if parts.len() != 2 {
            eprintln!("Invalid file arg '{}': expected path:DOSNAME", arg);
            std::process::exit(1);
        }

        let file_path = parts[0];
        let dos_name = parts[1];
        let fat_name = to_fat_name(dos_name);

        let contents = fs::read(file_path).unwrap_or_else(|e| {
            eprintln!("Failed to read '{}': {}", file_path, e);
            std::process::exit(1);
        });

        let cluster = img.add_file(&fat_name, &contents);
        eprintln!(
            "Added {} as {} (cluster {}, {} bytes)",
            file_path,
            dos_name,
            cluster,
            contents.len()
        );
    }

    fs::write(&output_path, img.as_bytes()).unwrap_or_else(|e| {
        eprintln!("Failed to write '{}': {}", output_path.display(), e);
        std::process::exit(1);
    });

    eprintln!(
        "Created floppy image: {} ({} bytes)",
        output_path.display(),
        img.as_bytes().len()
    );
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_to_fat_name() {
        assert_eq!(to_fat_name("STAGE2.BIN"), *b"STAGE2  BIN");
        assert_eq!(to_fat_name("IO.SYS"), *b"IO      SYS");
        assert_eq!(to_fat_name("COMMAND.COM"), *b"COMMAND COM");
        assert_eq!(to_fat_name("README.TXT"), *b"README  TXT");
        assert_eq!(to_fat_name("AUTOEXEC.BAT"), *b"AUTOEXECBAT");
    }
}
