"""
Konversi ONNX ke TFLite menggunakan onnxruntime + manual quantization
Alternatif tanpa TensorFlow yang berat.
"""
import sys, io
if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

import numpy as np
import onnxruntime as ort
from pathlib import Path
import json
import shutil
import struct

MODELS_DIR = Path("C:/pcs_project/training/models")
FLUTTER_MODELS = Path("C:/pcs_project/handtalk/assets/models")

def verify_onnx_model():
    """Verify ONNX model works correctly."""
    print("Verifying ONNX model...")
    
    onnx_path = str(MODELS_DIR / "bisindo_model.onnx")
    session = ort.InferenceSession(onnx_path)
    
    # Get model info
    input_info = session.get_inputs()[0]
    output_info = session.get_outputs()[0]
    
    print(f"  Input: {input_info.name}, shape={input_info.shape}, type={input_info.type}")
    print(f"  Output: {output_info.name}, shape={output_info.shape}, type={output_info.type}")
    
    # Test inference
    dummy = np.random.randn(1, 3, 224, 224).astype(np.float32)
    result = session.run(None, {input_info.name: dummy})
    
    print(f"  Output shape: {result[0].shape}")
    print(f"  Output sample: {result[0][0][:5]}")
    
    # Softmax
    exp_vals = np.exp(result[0][0] - np.max(result[0][0]))
    probs = exp_vals / exp_vals.sum()
    top_idx = np.argmax(probs)
    
    labels = list("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
    print(f"  Top prediction: {labels[top_idx]} ({probs[top_idx]*100:.1f}%)")
    print(f"  Model verified OK!")
    
    return True


def create_model_metadata():
    """Create comprehensive metadata for Flutter app."""
    print("\nCreating model metadata...")
    
    labels = list("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
    
    metadata = {
        "model_format": "onnx",
        "model_file": "bisindo_model.onnx",
        "labels": labels,
        "num_classes": 26,
        "image_size": 224,
        "input_name": "input",
        "output_name": "output",
        "input_shape": [1, 3, 224, 224],
        "input_format": "NCHW",
        "color_format": "RGB",
        "normalization": {
            "mean": [0.485, 0.456, 0.406],
            "std": [0.229, 0.224, 0.225]
        },
        "val_accuracy": 0.8308,
        "model_architecture": "MobileNetV2",
        "training_info": {
            "dataset": "sifaqeinstein/bisindo",
            "total_images": 10400,
            "images_per_class": 400,
            "framework": "PyTorch"
        }
    }
    
    # Save to Flutter assets
    FLUTTER_MODELS.mkdir(parents=True, exist_ok=True)
    
    labels_path = FLUTTER_MODELS / "labels.json"
    with open(labels_path, "w") as f:
        json.dump(metadata, f, indent=2)
    print(f"  Saved: {labels_path}")
    
    # Also save simple labels.txt
    txt_path = FLUTTER_MODELS / "labels.txt"
    with open(txt_path, "w") as f:
        for label in labels:
            f.write(f"{label}\n")
    print(f"  Saved: {txt_path}")
    
    return metadata


def copy_model_to_flutter():
    """Copy ONNX model to Flutter assets."""
    print("\nCopying model to Flutter project...")
    
    FLUTTER_MODELS.mkdir(parents=True, exist_ok=True)
    
    # Copy ONNX model
    src = MODELS_DIR / "bisindo_model.onnx"
    dst = FLUTTER_MODELS / "bisindo_model.onnx"
    shutil.copy2(src, dst)
    size_mb = dst.stat().st_size / (1024 * 1024)
    print(f"  Copied: bisindo_model.onnx ({size_mb:.2f} MB)")
    
    # Also copy TorchScript as backup
    src_pt = MODELS_DIR / "bisindo_model.pt"
    if src_pt.exists():
        dst_pt = FLUTTER_MODELS / "bisindo_model.pt"
        shutil.copy2(src_pt, dst_pt)
        size_mb = dst_pt.stat().st_size / (1024 * 1024)
        print(f"  Copied: bisindo_model.pt ({size_mb:.2f} MB)")


def main():
    print("=" * 50)
    print("  BISINDO Model - ONNX Verification & Setup")
    print("=" * 50)
    
    # Step 1: Verify ONNX model
    verify_onnx_model()
    
    # Step 2: Create metadata
    create_model_metadata()
    
    # Step 3: Copy to Flutter
    copy_model_to_flutter()
    
    print("\n" + "=" * 50)
    print("  DONE!")
    print("=" * 50)
    print("\nModel files in Flutter assets:")
    for f in sorted(FLUTTER_MODELS.iterdir()):
        if f.is_file() and f.name != '.gitkeep':
            size = f.stat().st_size / (1024 * 1024)
            print(f"  {f.name} ({size:.2f} MB)")
    
    print("\nNote: Using ONNX format for inference.")
    print("Flutter app will use onnxruntime package for inference.")
    print("Alternative: Use tflite_flutter with TorchScript model.")


if __name__ == "__main__":
    main()
