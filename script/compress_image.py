#!/usr/bin/env python3

"""compress_image.py

Small utility to compress PNG and JPEG images in a directory tree using
external tools (`pngquant` for PNG, `jpegoptim` for JPEG). Designed to be
run after building a static site (default target directory is `site`).

Behavior notes:
- PNG files are compressed with `pngquant` producing a temporary file which
  then replaces the original.
- JPEG files are processed with `jpegoptim` and overwritten in-place.
- The script runs compressions in parallel using a thread pool controlled by
  `THREADS_NUM`.
- This script modifies files in place; create backups or run on a copy if you
  want to preserve originals.
"""

import subprocess
from pathlib import Path
import os
import argparse

# Compression quality settings
JPG_QUALITY = 80       # JPEG quality (0-100), lower => smaller files
PNG_QUALITY = "60-80"  # pngquant quality range (min-max as percentages)
THREADS_NUM = 4        # Number of worker threads for parallel processing


def compress_image_once(file_path: Path) -> None:
    """Compress a single image file in-place.

    The function chooses the compression tool based on file extension:
    - .png -> pngquant (writes a temp file then replaces original)
    - .jpg/.jpeg -> jpegoptim (overwrites original)

    Errors are caught and printed; they do not stop processing other files.

    Args:
        file_path: Path object pointing to the image file to compress.
    """
    try:
        suffix = file_path.suffix.lower()

        if suffix == ".png":
            temp_file = file_path.with_suffix(".tmp.png")
            # Run pngquant to compress PNG into a temporary file
            subprocess.run([
                "pngquant", "--force",
                "--quality", PNG_QUALITY,
                "--output", str(temp_file),
                str(file_path)
            ], check=True)
            # Replace original with compressed file
            os.replace(temp_file, file_path)

        elif suffix in (".jpg", ".jpeg"):
            # Run jpegoptim to compress and strip metadata
            subprocess.run([
                "jpegoptim",
                "--max=" + str(JPG_QUALITY),
                "--strip-all",
                "--overwrite",
                str(file_path)
            ], check=True)

        # Log resulting file size in KB
        print(f"[compress] [info] {file_path} ({file_path.stat().st_size/1024:.1f} KB)")

    except Exception as e:
        # Print the error and continue
        print(f"[compress] [fail] {file_path}: {e}")


def compress_image(root_dir: str) -> None:
    """Recursively find PNG/JPEG images under `root_dir` and compress them.

    Files are discovered using pathlib's `rglob`. Compression tasks are
    dispatched to a thread pool for parallel execution.

    Args:
        root_dir: Root directory to search for image files.
    """
    image_exts = (".png", ".jpg", ".jpeg")
    image_files = []

    # Collect all supported image files recursively
    for ext in image_exts:
        image_files.extend(Path(root_dir).rglob(f"*{ext}"))

    # Compress images in parallel using a thread pool
    from concurrent.futures import ThreadPoolExecutor
    with ThreadPoolExecutor(max_workers=THREADS_NUM) as executor:
        executor.map(compress_image_once, image_files)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Compress PNG and JPEG images in a directory tree (in-place)."
    )
    parser.add_argument(
        "dir",
        type=str,
        nargs="?",
        default="site",
        help="Directory to compress images in (default: 'site')",
    )
    args = parser.parse_args()

    # Ensure target directory exists
    if not Path(args.dir).exists():
        print(f"[compress] [fail] directory '{args.dir}' does not exist!")
        raise SystemExit(1)

    compress_image(args.dir)
