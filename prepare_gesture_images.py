"""
Script untuk memilih 1 gambar terbaik per huruf BISINDO dari dataset Kaggle
dan mengompresnya ke format PNG (kompatibel Flutter) resolusi 480x480.

Dataset: kaggle:sifaqeinstein/bisindo
Output: handtalk/assets/images/gestures/alphabet_a.png ... alphabet_z.png
"""

import os
import sys
from pathlib import Path
from PIL import Image, ImageFilter, ImageStat

# Paths
DATASET_PATH = Path(r"C:\Users\User\.cache\kagglehub\datasets\sifaqeinstein\bisindo\versions\1\split\train\images")
OUTPUT_PATH = Path(r"C:\pcs_project\handtalk\assets\images\gestures")

# Settings
OUTPUT_SIZE = (480, 480)
LETTERS = list("ABCDEFGHIJKLMNOPQRSTUVWXYZ")


def calculate_sharpness(image: Image.Image) -> float:
    """Calculate image sharpness using Laplacian variance."""
    gray = image.convert("L")
    # Use edge detection as proxy for sharpness
    edges = gray.filter(ImageFilter.FIND_EDGES)
    stat = ImageStat.Stat(edges)
    return stat.var[0]  # Higher variance = sharper image


def calculate_brightness(image: Image.Image) -> float:
    """Calculate average brightness."""
    gray = image.convert("L")
    stat = ImageStat.Stat(gray)
    return stat.mean[0]


def select_best_image(folder: Path) -> Path:
    """
    Select the best image from a folder based on:
    1. Sharpness (most important)
    2. Good brightness (not too dark, not too bright)
    
    Prefer non-augmented images (without 'aug' in name) if available.
    """
    images = list(folder.glob("*.jpg")) + list(folder.glob("*.png")) + list(folder.glob("*.jpeg"))
    
    if not images:
        raise FileNotFoundError(f"No images found in {folder}")
    
    # Prefer original (non-augmented) images
    originals = [img for img in images if "aug" not in img.stem.lower()]
    candidates = originals if originals else images[:50]  # Limit to 50 for speed
    
    # If still too many, take first 20
    if len(candidates) > 20:
        candidates = candidates[:20]
    
    best_image = None
    best_score = -1
    
    for img_path in candidates:
        try:
            with Image.open(img_path) as img:
                img = img.convert("RGB")
                
                # Calculate metrics
                sharpness = calculate_sharpness(img)
                brightness = calculate_brightness(img)
                
                # Score: prefer sharp images with good brightness (100-200 range)
                brightness_score = 1.0 - abs(brightness - 140) / 140  # Peak at 140
                brightness_score = max(0, brightness_score)
                
                score = sharpness * 0.7 + brightness_score * 100 * 0.3
                
                if score > best_score:
                    best_score = score
                    best_image = img_path
        except Exception as e:
            continue
    
    if best_image is None:
        # Fallback: just pick the first image
        best_image = images[0]
    
    return best_image


def process_image(input_path: Path, output_path: Path):
    """Open image, resize to 480x480 with padding, save as optimized PNG."""
    with Image.open(input_path) as img:
        img = img.convert("RGB")
        
        # Resize maintaining aspect ratio with white padding
        img.thumbnail(OUTPUT_SIZE, Image.Resampling.LANCZOS)
        
        # Create square canvas
        canvas = Image.new("RGB", OUTPUT_SIZE, (255, 255, 255))
        
        # Center the image
        x_offset = (OUTPUT_SIZE[0] - img.width) // 2
        y_offset = (OUTPUT_SIZE[1] - img.height) // 2
        canvas.paste(img, (x_offset, y_offset))
        
        # Save as optimized PNG
        canvas.save(output_path, "PNG", optimize=True)


def main():
    print("=" * 60)
    print("  BISINDO Gesture Image Preparation")
    print("  Dataset -> App Assets")
    print("=" * 60)
    print()
    
    # Verify dataset exists
    if not DATASET_PATH.exists():
        print(f"ERROR: Dataset not found at {DATASET_PATH}")
        sys.exit(1)
    
    # Create output directory
    OUTPUT_PATH.mkdir(parents=True, exist_ok=True)
    
    # Remove old .gitkeep if exists
    gitkeep = OUTPUT_PATH / ".gitkeep"
    if gitkeep.exists():
        gitkeep.unlink()
    
    print(f"Dataset: {DATASET_PATH}")
    print(f"Output:  {OUTPUT_PATH}")
    print(f"Size:    {OUTPUT_SIZE[0]}x{OUTPUT_SIZE[1]} PNG")
    print()
    
    total_size = 0
    processed = 0
    
    for letter in LETTERS:
        letter_folder = DATASET_PATH / letter
        
        if not letter_folder.exists():
            print(f"  [SKIP] {letter} - folder not found")
            continue
        
        try:
            # Select best image
            best_img = select_best_image(letter_folder)
            
            # Output filename
            output_file = OUTPUT_PATH / f"alphabet_{letter.lower()}.png"
            
            # Process and save
            process_image(best_img, output_file)
            
            file_size = output_file.stat().st_size
            total_size += file_size
            processed += 1
            
            print(f"  [OK] {letter} -> {output_file.name} ({file_size/1024:.1f} KB) from {best_img.name}")
            
        except Exception as e:
            print(f"  [ERROR] {letter} - {e}")
    
    print()
    print("-" * 60)
    print(f"  Done! {processed}/{len(LETTERS)} images processed")
    print(f"  Total size: {total_size/1024:.1f} KB ({total_size/1024/1024:.2f} MB)")
    print(f"  Output: {OUTPUT_PATH}")
    print("-" * 60)


if __name__ == "__main__":
    main()
