#!/usr/bin/env python3

import subprocess
from pathlib import Path
import os
import argparse

# Compression quality settings
JPG_QUALITY = 80      # 0-100, higher value means better quality
PNG_QUALITY = "60-80" # Quality range for pngquant (0-100)
THREADS_NUM = 4       # Number of parallel threads for compression

def compress_image_once(file_path):
    """
    Compress a single image file using appropriate tool based on file extension.

    Args:
        file_path: Path object pointing to the image file to compress
    """
    try:
        # Handle PNG files with pngquant
        if file_path.suffix.lower() == ".png":
            temp_file = file_path.with_suffix(".tmp.png")
            # Use pngquant for PNG compression with quality range
            subprocess.run([
                "pngquant", "--force",
                "--quality", PNG_QUALITY,
                "--output", str(temp_file),
                str(file_path)
            ], check=True)
            # Replace original file with compressed version
            os.replace(temp_file, file_path)

        # Handle JPEG files with jpegoptim
        elif file_path.suffix.lower() in (".jpg", ".jpeg"):
            # Use jpegoptim for JPEG compression
            subprocess.run([
                "jpegoptim",
                "--max=" + str(JPG_QUALITY),  # Set maximum quality level
                "--strip-all",                 # Remove all metadata
                "--overwrite",                 # Replace original file
                str(file_path)
            ], check=True)

        # Print compression result with file size
        print(f"Compressed: {file_path} ({file_path.stat().st_size/1024:.1f} KB)")

    except Exception as e:
        print(f"Failed to compress {file_path}: {str(e)}")

def compress_image(root_dir):
    """
    Recursively find and compress all images in directory tree using multi-threading.

    Args:
        root_dir: Root directory to search for image files
    """
    # Supported image file extensions
    image_exts = (".png", ".jpg", ".jpeg")
    image_files = []

    # Recursively find all image files in directory tree
    for ext in image_exts:
        image_files.extend(Path(root_dir).rglob("*" + ext))

    # Use thread pool for parallel compression
    from concurrent.futures import ThreadPoolExecutor
    with ThreadPoolExecutor(max_workers=THREADS_NUM) as executor:
        # Process all images in parallel
        executor.map(compress_image_once, image_files)

if __name__ == "__main__":
    # Set up command line argument parser
    parser = argparse.ArgumentParser(
        description="Compress PNG and JPEG images in a directory tree"
    )
    parser.add_argument(
        "dir",
        type=str,
        nargs="?",
        default="site",
        help="Directory to compress images in (default: 'site')"
    )
    args = parser.parse_args()

    # Validate that target directory exists
    if not Path(args.dir).exists():
        print(f"Error: Directory '{args.dir}' does not exist!")
        exit(1)

    # Start compression process
    compress_image(args.dir)
