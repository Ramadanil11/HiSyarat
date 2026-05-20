"""Convert PyTorch model to TFLite via ONNX -> TF -> TFLite"""
import sys, io
if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

import numpy as np
import json
import shutil
from pathlib import Path

MODELS_DIR = Path("C:/pcs_project/training/models")
FLUTTER_MODELS = Path("C:/pcs_project/handtalk/assets/models")

def convert_onnx_to_tflite():
    """Convert ONNX model to TFLite using TensorFlow."""
    print("Converting ONNX -> TFLite...")
    
    import tensorflow as tf
    import onnxruntime as ort
    
    onnx_path = str(MODELS_DIR / "bisindo_model.onnx")
    
    # First, let's create a TF model that mimics the ONNX model
    # by using tf.lite.TFLiteConverter with a concrete function
    
    # Load ONNX and get input/output info
    session = ort.InferenceSession(onnx_path)
    input_info = session.get_inputs()[0]
    output_info = session.get_outputs()[0]
    print(f"  ONNX Input: {input_info.shape}")
    print(f"  ONNX Output: {output_info.shape}")
    
    # Method: Use tf.function wrapper around ONNX inference
    # Better method: Convert PyTorch -> SavedModel directly
    
    # Let's use a simpler approach: recreate the model in TF
    # and load the weights from PyTorch
    
    import torch
    from torchvision import models
    import torch.nn as nn
    
    # Load PyTorch model
    checkpoint = torch.load(
        str(MODELS_DIR / "best_model.pth"), 
        map_location='cpu', 
        weights_only=False
    )
    
    # Recreate PyTorch model
    model = models.mobilenet_v2(weights=None)
    num_features = model.classifier[1].in_features
    model.classifier = nn.Sequential(
        nn.Dropout(p=0.3),
        nn.Linear(num_features, 256),
        nn.ReLU(),
        nn.Dropout(p=0.2),
        nn.Linear(256, 26)
    )
    model.load_state_dict(checkpoint['model_state_dict'])
    model.eval()
    
    # Export to ONNX with fixed batch size
    print("  Re-exporting ONNX with fixed batch...")
    dummy_input = torch.randn(1, 3, 224, 224)
    fixed_onnx_path = str(MODELS_DIR / "bisindo_fixed.onnx")
    
    torch.onnx.export(
        model, dummy_input, fixed_onnx_path,
        export_params=True, opset_version=13,
        do_constant_folding=True,
        input_names=['input'], output_names=['output']
    )
    
    # Now convert using tf2onnx reverse or direct TFLite conversion
    # Use the representative dataset approach
    
    print("  Converting to TFLite via concrete function...")
    
    # Create a TF concrete function from the ONNX model
    # Simpler approach: use onnxruntime to create a wrapper
    
    # Actually, let's use the simplest working approach:
    # Create a TF SavedModel that wraps ONNX inference
    
    # Alternative: Direct conversion using tf-onnx
    try:
        import onnx
        from onnx_tf.backend import prepare
        
        print("  Using onnx-tf for conversion...")
        onnx_model = onnx.load(fixed_onnx_path)
        tf_rep = prepare(onnx_model)
        
        saved_model_path = str(MODELS_DIR / "tf_saved_model")
        tf_rep.export_graph(saved_model_path)
        print(f"  SavedModel exported to: {saved_model_path}")
        
        # Convert SavedModel to TFLite
        converter = tf.lite.TFLiteConverter.from_saved_model(saved_model_path)
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        
        # Representative dataset for quantization
        def representative_dataset():
            for _ in range(100):
                data = np.random.randn(1, 3, 224, 224).astype(np.float32)
                yield [data]
        
        converter.representative_dataset = representative_dataset
        converter.target_spec.supported_types = [tf.float16]
        
        tflite_model = converter.convert()
        
        tflite_path = MODELS_DIR / "bisindo_model.tflite"
        with open(tflite_path, 'wb') as f:
            f.write(tflite_model)
        
        size_mb = tflite_path.stat().st_size / (1024 * 1024)
        print(f"  TFLite model saved: {tflite_path} ({size_mb:.2f} MB)")
        
        return str(tflite_path)
        
    except ImportError:
        print("  onnx-tf not available, trying alternative method...")
    
    # Alternative: Use tf.lite with a simple wrapper model
    print("  Creating TFLite from scratch using TF Keras...")
    
    # Recreate MobileNetV2 in TF/Keras and transfer weights
    tf_model = tf.keras.applications.MobileNetV2(
        input_shape=(224, 224, 3),
        include_top=False,
        weights=None,
        pooling='avg'
    )
    
    # Add custom classifier
    x = tf_model.output
    x = tf.keras.layers.Dropout(0.3)(x)
    x = tf.keras.layers.Dense(256, activation='relu')(x)
    x = tf.keras.layers.Dropout(0.2)(x)
    outputs = tf.keras.layers.Dense(26)(x)
    
    full_model = tf.keras.Model(inputs=tf_model.input, outputs=outputs)
    
    # Note: Weight transfer from PyTorch to TF is complex due to different
    # layer ordering. For now, we'll save the model structure and note
    # that proper weight transfer would be needed.
    
    # For a working demo, let's just convert the ONNX model directly
    # using the simpler approach with onnxruntime
    
    # Fallback: Create a simple TFLite model from the ONNX inference
    print("  Using ONNX model directly (TFLite conversion skipped)")
    print("  The app will use ONNX Runtime for inference instead")
    
    return None


def copy_to_flutter(tflite_path=None):
    """Copy model files to Flutter assets."""
    print("\nCopying to Flutter assets...")
    FLUTTER_MODELS.mkdir(parents=True, exist_ok=True)
    
    if tflite_path and Path(tflite_path).exists():
        dst = FLUTTER_MODELS / "bisindo_model.tflite"
        shutil.copy2(tflite_path, dst)
        size_mb = dst.stat().st_size / (1024 * 1024)
        print(f"  Copied: bisindo_model.tflite ({size_mb:.2f} MB)")
    
    # Always copy ONNX as backup/alternative
    onnx_src = MODELS_DIR / "bisindo_model.onnx"
    if onnx_src.exists():
        dst = FLUTTER_MODELS / "bisindo_model.onnx"
        shutil.copy2(onnx_src, dst)
        size_mb = dst.stat().st_size / (1024 * 1024)
        print(f"  Copied: bisindo_model.onnx ({size_mb:.2f} MB)")
    
    # Labels
    labels = list("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
    metadata = {
        "labels": labels,
        "num_classes": 26,
        "image_size": 224,
        "normalization": {"mean": [0.485, 0.456, 0.406], "std": [0.229, 0.224, 0.225]},
        "input_format": "NCHW",
        "val_accuracy": 0.8308
    }
    
    with open(FLUTTER_MODELS / "labels.json", "w") as f:
        json.dump(metadata, f, indent=2)
    
    with open(FLUTTER_MODELS / "labels.txt", "w") as f:
        for l in labels:
            f.write(f"{l}\n")
    
    print("  Labels saved!")


if __name__ == "__main__":
    print("=" * 50)
    print("  BISINDO - TFLite Conversion")
    print("=" * 50)
    
    tflite_path = convert_onnx_to_tflite()
    copy_to_flutter(tflite_path)
    
    print("\n" + "=" * 50)
    print("  DONE!")
    print("=" * 50)
    
    print("\nFlutter assets/models/:")
    for f in sorted(FLUTTER_MODELS.iterdir()):
        if f.is_file() and f.name != '.gitkeep':
            size = f.stat().st_size / (1024 * 1024)
            print(f"  {f.name} ({size:.2f} MB)")
