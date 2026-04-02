// compress_image.js
// Utility script to find raster images under a directory, convert them to
// WebP using `sharp`, and remove the original files. Intended for use after
// building a static site (`site` by default).
//
// Notes:
// - This script is destructive: original PNG/JPG files are deleted after
//   successful conversion to WebP. Run on a copy or commit changes beforehand
//   if you want to keep originals.
// - Concurrency is controlled by THREADS_NUM to avoid excessive parallelism.
// - Output files are written alongside originals with `.webp` extension.

import { promises as fs } from "fs";
import path from "path";
import sharp from "sharp";

// Compression quality settings
// IMG_QUALITY: 0-100 (higher => better quality and larger file size)
const IMG_QUALITY = 80;
// THREADS_NUM: number of concurrent workers compressing images
const THREADS_NUM = 4;

// Recursively find image files under `dir`.
// Returns an array of absolute file paths for .png, .jpg, .jpeg files.
async function findImages(dir) {
    let results = [];
    const entries = await fs.readdir(dir, { withFileTypes: true });

    for (const entry of entries) {
        const fullPath = path.join(dir, entry.name);

        if (entry.isDirectory()) {
            // Recurse into subdirectories
            results = results.concat(await findImages(fullPath));
        }
        else {
            const ext = path.extname(entry.name).toLowerCase();
            if ([".png", ".jpg", ".jpeg"].includes(ext)) {
                results.push(fullPath);
            }
        }
    }

    return results;
}

// Run an array of task functions with a maximum concurrency of `limit`.
// Each task is expected to be an async function that performs one unit of work.
async function runWithConcurrency(tasks, limit) {
    const queue = [];
    let i = 0;

    async function worker() {
        while (i < tasks.length) {
            const currentIndex = i++;
            // Execute the task and wait for it to finish before taking next
            await tasks[currentIndex]();
        }
    }

    // Start `limit` workers in parallel
    for (let j = 0; j < limit; j++) {
        queue.push(worker());
    }

    await Promise.all(queue);
}

// Convert a single image file to WebP and remove the original file on success.
// This function is robust to unsupported file extensions and logs failures
// without throwing, so the concurrency loop can continue processing others.
async function compressImageOnce(filePath) {
    try {
        const ext = path.extname(filePath).toLowerCase();

        if (![".png", ".jpg", ".jpeg"].includes(ext)) return;

        // Replace original extension with .webp
        const outputPath = filePath.replace(/\.(png|jpg|jpeg)$/i, ".webp");

        // Use sharp to write WebP with configured quality
        await sharp(filePath)
            .webp({ quality: IMG_QUALITY })
            .toFile(outputPath);

        // Remove the original file after successful conversion
        await fs.unlink(filePath);

        console.log(`[compress] [info] ${filePath} -> ${outputPath}`);
    }
    catch (err) {
        // Log error and continue processing other images
        console.error(`[compress] [fail] ${filePath}: ${err.message}`);
    }
}

// Find images under `rootDir` and compress them with limited concurrency.
async function compressImage(rootDir) {
    const images = await findImages(rootDir);
    console.log(`[compress] [info] found ${images.length} images`);

    // Wrap each file path into a task function so runWithConcurrency can call them
    const tasks = images.map((file) => () => compressImageOnce(file));
    await runWithConcurrency(tasks, THREADS_NUM);
    console.log("[compress] [info] done!");
}

// Entry point: accept an optional directory argument (defaults to `site`).
// Validates the directory exists and then starts compression.
async function main() {
    const args_dir = process.argv[2] || "site";

    try {
        await fs.access(args_dir);
    }
    catch {
        console.error(`[compress] [fail] directory "${args_dir}" does not exist!`);
        process.exit(1);
    }

    // Note: do not await here so the top-level promise is allowed to settle
    // if you prefer to catch all errors, you can `await` compressImage(args_dir)
    compressImage(args_dir);
}

main();
