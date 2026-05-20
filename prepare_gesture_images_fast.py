"""
Fast script: Pick first non-augmented image per letter, resize to 480x480 PNG.
"""
import os
from pathlib import Path
from PIL import Image

DATASET_PATH = Path(r"C:\Users\User\.cache\kagglehub\datasets\sifaqeinstein\bisindo\versions\1\split\train\images")
OUTPUT_PATH = Path(r"C:\pcs_project\handtalk\assets\images\gestures")
OUTPUT_SIZE = (480, 480)
LETTERS = list("ABCDEFGHIJKLMNOPQRSTUVWXYZ")

def main():
    print("BISINDO Gesture Image Preparation (Fast)")
    print("-" * 50)
    
    OUTPUT_PATH.mkdir(parents=True, exist_ok=True)
    
    # Remove .gitkeep
    gitkeep = OUTPUT_PATH / ".gitkeep"
    if gitkeep.exists():
        gitkeep.unlink()
    
    total_size = 0
    processed = 0
    
    for letter in LETTERS:
        letter_folder = DATASET_PATH / letter
        if not letter_folder.exists():
            print(f"  [SKIP] {letter}")
            continue
        
        # Get all images
        images = sorted(letter_folder.glob("*.jpg"))
        if not images:
            images = sorted(letter_folder.glob("*.png"))
        if not images:
            print(f"  [SKIP] {letter} - no images")
            continue
        
        # Pick first image (they are already good quality)
        # Prefer non-aug if available
        non_aug = [f for f in images if "aug" not in f.stem]
        pick = non_aug[0] if non_aug else images[0]
        
        output_file = OUTPUT_PATH / f"alphabet_{letter.lower()}.png"
        
        try:
            with Image.open(pick) as img:
                img = img.convert("RGB")
                img.thumbnail(OUTPUT_SIZE, Image.Resampling.LANCZOS)
                
                # Center on white canvas
                canvas = Image.new("RGB", OUTPUT_SIZE, (255, 255, 255))
                x = (OUTPUT_SIZE[0] - img.width) // 2
                y = (OUTPUT_SIZE[1] - img.height) // 2
                canvas.paste(img, (x, y))
                canvas.save(output_file, "PNG", optimize=True)
            
            file_size = output_file.stat().st_size
            total_size += file_size
            processed += 1
            print(f"  [OK] {letter} -> {output_file.name} ({file_size//1024} KB)")
        except Exception as e:
            print(f"  [ERR] {letter} - {e}")
    
    print("-" * 50)
    print(f"Done! {processed}/26 images, total {total_size//1024} KB ({total_size//1024//1024} MB)")

if __name__ == "__main__":
    main()
