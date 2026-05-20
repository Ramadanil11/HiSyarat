"""
=============================================================
HandTalk BISINDO - Step 4: Integrasi ke Flutter
=============================================================
Script ini membantu setup integrasi model ke Flutter project:
1. Copy model files ke assets
2. Verifikasi pubspec.yaml
3. Setup Android build configuration untuk TFLite
=============================================================
"""

import os
import json
import shutil
from pathlib import Path

# Paths
TRAINING_DIR = Path(__file__).parent
MODELS_DIR = TRAINING_DIR / "models"
FLUTTER_DIR = Path("C:/pcs_project/handtalk")
FLUTTER_ASSETS = FLUTTER_DIR / "assets"
FLUTTER_MODELS = FLUTTER_ASSETS / "models"
ANDROID_DIR = FLUTTER_DIR / "android"


def copy_model_files():
    """Copy model dan label files ke Flutter assets."""
    print("\n📦 Copying model files to Flutter assets...")
    
    FLUTTER_MODELS.mkdir(parents=True, exist_ok=True)
    
    files_to_copy = [
        "bisindo_model.tflite",
        "bisindo_model.onnx",
        "bisindo_model.pt",
    ]
    
    copied = 0
    for filename in files_to_copy:
        src = MODELS_DIR / filename
        if src.exists():
            dst = FLUTTER_MODELS / filename
            shutil.copy2(src, dst)
            size_mb = dst.stat().st_size / (1024 * 1024)
            print(f"   ✅ {filename} ({size_mb:.2f} MB)")
            copied += 1
    
    # Copy/create labels
    model_info = MODELS_DIR / "model_info.json"
    class_mapping = MODELS_DIR / "class_mapping.json"
    
    labels_data = {}
    class_names = []
    
    if model_info.exists():
        with open(model_info) as f:
            info = json.load(f)
            class_names = info.get("class_names", [])
            labels_data = {
                "labels": class_names,
                "num_classes": len(class_names),
                "image_size": info.get("image_size", 224),
                "normalization": info.get("normalization", {
                    "mean": [0.485, 0.456, 0.406],
                    "std": [0.229, 0.224, 0.225]
                }),
                "input_format": "RGB",
                "input_shape": [1, 3, 224, 224],
                "test_accuracy": info.get("test_accuracy", 0),
            }
    elif class_mapping.exists():
        with open(class_mapping) as f:
            mapping = json.load(f)
            class_names = mapping.get("class_names", [])
            labels_data = {
                "labels": class_names,
                "num_classes": len(class_names),
                "image_size": 224,
                "normalization": {
                    "mean": [0.485, 0.456, 0.406],
                    "std": [0.229, 0.224, 0.225]
                },
                "input_format": "RGB",
                "input_shape": [1, 3, 224, 224],
            }
    
    if labels_data:
        labels_path = FLUTTER_MODELS / "labels.json"
        with open(labels_path, "w") as f:
            json.dump(labels_data, f, indent=2)
        print(f"   ✅ labels.json ({len(class_names)} classes)")
        
        # Also create labels.txt
        txt_path = FLUTTER_MODELS / "labels.txt"
        with open(txt_path, "w") as f:
            for name in class_names:
                f.write(f"{name}\n")
        print(f"   ✅ labels.txt")
        copied += 2
    
    print(f"\n   Total files copied: {copied}")
    return copied > 0


def setup_android_config():
    """Setup Android build.gradle untuk TFLite support."""
    print("\n🤖 Setting up Android configuration...")
    
    # Check app/build.gradle
    app_gradle = ANDROID_DIR / "app" / "build.gradle"
    if not app_gradle.exists():
        # Try .kts variant
        app_gradle = ANDROID_DIR / "app" / "build.gradle.kts"
    
    if app_gradle.exists():
        content = app_gradle.read_text()
        
        # Check if noCompress is already set for tflite
        if 'tflite' not in content:
            # Add noCompress for tflite files
            if 'aaptOptions' not in content:
                # Add aaptOptions block
                insert_text = """
    // TFLite model files should not be compressed
    aaptOptions {
        noCompress "tflite"
    }
"""
                # Find android { block and add after it
                if 'android {' in content:
                    content = content.replace(
                        'android {',
                        'android {\n' + insert_text,
                        1
                    )
                    app_gradle.write_text(content)
                    print("   ✅ Added aaptOptions for TFLite")
                else:
                    print("   ⚠️ Could not find android block in build.gradle")
            else:
                print("   ℹ️ aaptOptions already exists")
        else:
            print("   ✅ TFLite config already present")
    else:
        print(f"   ⚠️ build.gradle not found at {app_gradle}")
    
    return True


def verify_pubspec():
    """Verify pubspec.yaml has correct dependencies."""
    print("\n📋 Verifying pubspec.yaml...")
    
    pubspec_path = FLUTTER_DIR / "pubspec.yaml"
    if not pubspec_path.exists():
        print("   ❌ pubspec.yaml not found!")
        return False
    
    content = pubspec_path.read_text()
    
    checks = {
        "tflite_flutter": "tflite_flutter" in content,
        "camera": "camera:" in content,
        "assets/models/": "assets/models/" in content,
    }
    
    all_ok = True
    for item, found in checks.items():
        status = "✅" if found else "❌"
        print(f"   {status} {item}")
        if not found:
            all_ok = False
    
    return all_ok


def print_next_steps():
    """Print next steps for the developer."""
    print("\n" + "=" * 60)
    print("  📋 LANGKAH SELANJUTNYA")
    print("=" * 60)
    
    print("""
1. Jalankan 'flutter pub get' di folder handtalk:
   cd C:\\pcs_project\\handtalk
   flutter pub get

2. Build dan test di Android device:
   flutter run

3. Jika ada error TFLite, pastikan:
   - File .tflite ada di assets/models/
   - pubspec.yaml sudah include assets/models/
   - Android build.gradle punya aaptOptions noCompress "tflite"

4. Untuk meningkatkan akurasi:
   - Kumpulkan lebih banyak data
   - Re-train model dengan data baru
   - Jalankan ulang pipeline: 01 → 02 → 03 → 04

5. Fitur yang sudah terintegrasi:
   ✅ Real-time camera detection dengan AI
   ✅ Hybrid mode (AI + Rule-based fallback)
   ✅ Confidence score display
   ✅ AI/Rule badge indicator
   ✅ Sentence builder
   ✅ Text-to-Speech output
""")


def main():
    print("=" * 60)
    print("  HANDTALK BISINDO - Flutter Integration")
    print("=" * 60)
    
    # Step 1: Copy model files
    has_models = copy_model_files()
    
    # Step 2: Setup Android config
    setup_android_config()
    
    # Step 3: Verify pubspec
    verify_pubspec()
    
    # Step 4: Print next steps
    print_next_steps()
    
    if has_models:
        print("✅ Integrasi selesai! Model siap digunakan.")
    else:
        print("⚠️ Model belum tersedia. Jalankan training pipeline dulu:")
        print("   python 01_download_dataset.py")
        print("   python 02_train_model.py")
        print("   python 03_export_tflite.py")
        print("   python 04_integrate_flutter.py")


if __name__ == "__main__":
    main()
