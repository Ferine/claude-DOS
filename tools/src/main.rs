mod fatimg;

use fatimg::fat12::Fat12Image;
use fatimg::fat16::Fat16Image;
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

    // Check for --hd flag
    let hd_mode = args.iter().any(|a| a == "--hd");
    let filtered_args: Vec<&String> = args.iter().filter(|a| *a != "--hd").collect();

    if hd_mode {
        run_hd_mode(&filtered_args);
    } else {
        run_floppy_mode(&filtered_args);
    }
}

fn run_floppy_mode(args: &[&String]) {
    if args.len() < 3 {
        eprintln!("Usage: mkfloppy <output.img> <vbr.bin> [file1:DOSNAME file2:DOSNAME ...]");
        eprintln!("  DOSNAME can be a simple filename (STAGE2.BIN) or include a path (DATOS/FILE.FLI)");
        eprintln!("  Example: mkfloppy floppy.img vbr.bin stage2.bin:STAGE2.BIN data.fli:DATOS/DATA.FLI");
        std::process::exit(1);
    }

    let output_path = PathBuf::from(args[1].as_str());
    let vbr_path = PathBuf::from(args[2].as_str());

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
        let dos_path = parts[1];

        let contents = fs::read(file_path).unwrap_or_else(|e| {
            eprintln!("Failed to read '{}': {}", file_path, e);
            std::process::exit(1);
        });

        // Check if dos_path contains a directory component
        let cluster = if dos_path.contains('/') {
            let filename = dos_path.rsplit('/').next().unwrap();
            let fat_name = to_fat_name(filename);
            let c = img.add_file_with_path(dos_path, &fat_name, &contents);
            eprintln!(
                "Added {} as {} (cluster {}, {} bytes)",
                file_path, dos_path, c, contents.len()
            );
            c
        } else {
            let fat_name = to_fat_name(dos_path);
            let c = img.add_file(&fat_name, &contents);
            eprintln!(
                "Added {} as {} (cluster {}, {} bytes)",
                file_path, dos_path, c, contents.len()
            );
            c
        };
        let _ = cluster;
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

fn run_hd_mode(args: &[&String]) {
    if args.len() < 2 {
        eprintln!("Usage: mkfloppy --hd <output.img> [file1:DOSNAME ...]");
        std::process::exit(1);
    }

    let output_path = PathBuf::from(args[1].as_str());

    let mut img = Fat16Image::new();
    img.write_boot_sector();

    // Add files
    for arg in &args[2..] {
        let parts: Vec<&str> = arg.splitn(2, ':').collect();
        if parts.len() != 2 {
            eprintln!("Invalid file arg '{}': expected path:DOSNAME", arg);
            std::process::exit(1);
        }

        let file_path = parts[0];
        let dos_path = parts[1];

        let contents = fs::read(file_path).unwrap_or_else(|e| {
            eprintln!("Failed to read '{}': {}", file_path, e);
            std::process::exit(1);
        });

        // Check if dos_path contains a directory component
        let c = if dos_path.contains('/') {
            let filename = dos_path.rsplit('/').next().unwrap();
            let fat_name = to_fat_name(filename);
            img.add_file_with_path(dos_path, &fat_name, &contents)
        } else {
            let fat_name = to_fat_name(dos_path);
            img.add_file(&fat_name, &contents)
        };
        eprintln!(
            "Added {} as {} (cluster {}, {} bytes)",
            file_path, dos_path, c, contents.len()
        );
    }

    fs::write(&output_path, img.as_bytes()).unwrap_or_else(|e| {
        eprintln!("Failed to write '{}': {}", output_path.display(), e);
        std::process::exit(1);
    });

    eprintln!(
        "Created HD image: {} ({} bytes, {} MB)",
        output_path.display(),
        img.as_bytes().len(),
        img.as_bytes().len() / (1024 * 1024)
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
