"""
=============================================================
HandTalk BISINDO - Step 3: Export Model ke TFLite
=============================================================
Script ini mengkonversi model PyTorch ke TensorFlow Lite
untuk deployment di aplikasi Android Flutter.

Pipeline: PyTorch → ONNX → TFLite
=============================================================
"""

import os
import sys
import io
import json
import shutil
import numpy as np
from pathlib import Path

# Fix Windows console encoding
if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

import torch
import torch.nn as nn
from torchvision import models

# ============================================================
# KONFIGURASI
# ============================================================
BASE_DIR = Path(__file__).parent
MODELS_DIR = BASE_DIR / "models"
FLUTTER_MODELS_DIR = Path("C:/pcs_project/handtalk/assets/models")

IMAGE_SIZE = 224
DEVICE = torch.device("cpu")  # Export selalu di CPU


# ============================================================
# LOAD MODEL
# ============================================================
def load_trained_model():
    """Load model PyTorch yang sudah ditraining."""
    print("\n📂 Loading trained model...")
    
    model_path = MODELS_DIR / "best_model.pth"
    if not model_path.exists():
        print(f"❌ Model tidak ditemukan: {model_path}")
        print("   Jalankan 02_train_model.py terlebih dahulu.")
        sys.exit(1)
    
    # Load checkpoint
    checkpoint = torch.load(model_path, map_location=DEVICE, weights_only=False)
    
    num_classes = checkpoint['num_classes']
    class_names = checkpoint['class_names']
    val_acc = checkpoint['val_acc']
    
    print(f"   Num classes: {num_classes}")
    print(f"   Classes: {class_names}")
    print(f"   Val accuracy: {val_acc:.4f}")
    
    # Recreate model architecture
    model = models.mobilenet_v2(weights=None)
    num_features = model.classifier[1].in_features
    model.classifier = nn.Sequential(
        nn.Dropout(p=0.3),
        nn.Linear(num_features, 256),
        nn.ReLU(),
        nn.Dropout(p=0.2),
        nn.Linear(256, num_classes)
    )
    
    # Load weights
    model.load_state_dict(checkpoint['model_state_dict'])
    model.eval()
    model.to(DEVICE)
    
    print("   ✅ Model loaded successfully!")
    
    return model, num_classes, class_names


# ============================================================
# EXPORT KE ONNX
# ============================================================
def export_to_onnx(model):
    """Export model PyTorch ke format ONNX."""
    print("\n📦 Exporting ke ONNX...")
    
    onnx_path = MODELS_DIR / "bisindo_model.onnx"
    
    # Dummy input
    dummy_input = torch.randn(1, 3, IMAGE_SIZE, IMAGE_SIZE).to(DEVICE)
    
    # Export
    torch.onnx.export(
        model,
        dummy_input,
        str(onnx_path),
        export_params=True,
        opset_version=13,
        do_constant_folding=True,
        input_names=['input'],
        output_names=['output'],
        dynamic_axes={
            'input': {0: 'batch_size'},
            'output': {0: 'batch_size'}
        }
    )
    
    # Verify ONNX model
    import onnx
    onnx_model = onnx.load(str(onnx_path))
    onnx.checker.check_model(onnx_model)
    
    file_size = onnx_path.stat().st_size / (1024 * 1024)
    print(f"   ✅ ONNX model saved: {onnx_path}")
    print(f"   📏 Size: {file_size:.2f} MB")
    
    return onnx_path


# ============================================================
# EXPORT KE TFLITE
# ============================================================
def export_to_tflite_via_onnx(onnx_path):
    """Konversi ONNX ke TFLite."""
    print("\n📦 Converting ONNX → TFLite...")
    
    try:
        # Method 1: Menggunakan onnx2tf atau onnx-tf
        import onnxruntime as ort
        
        # Verifikasi ONNX model berjalan
        session = ort.InferenceSession(str(onnx_path))
        dummy = np.random.randn(1, 3, IMAGE_SIZE, IMAGE_SIZE).astype(np.float32)
        result = session.run(None, {'input': dummy})
        print(f"   ✅ ONNX inference test passed! Output shape: {result[0].shape}")
        
    except Exception as e:
        print(f"   ⚠️ ONNX runtime test: {e}")
    
    return onnx_path


def export_tflite_via_torch(model, num_classes, class_names):
    """Export langsung dari PyTorch ke TFLite menggunakan ai_edge_torch."""
    print("\n📦 Mencoba export via ai_edge_torch...")
    
    try:
        import ai_edge_torch
        
        dummy_input = (torch.randn(1, 3, IMAGE_SIZE, IMAGE_SIZE).to(DEVICE),)
        
        edge_model = ai_edge_torch.convert(model, dummy_input)
        
        tflite_path = MODELS_DIR / "bisindo_model.tflite"
        edge_model.export(str(tflite_path))
        
        file_size = tflite_path.stat().st_size / (1024 * 1024)
        print(f"   ✅ TFLite model saved: {tflite_path}")
        print(f"   📏 Size: {file_size:.2f} MB")
        
        return tflite_path
        
    except ImportError:
        print("   ⚠️ ai_edge_torch tidak tersedia")
        return None
    except Exception as e:
        print(f"   ⚠️ ai_edge_torch error: {e}")
        return None


def export_tflite_via_tf(onnx_path):
    """Export ONNX → TF SavedModel → TFLite."""
    print("\n📦 Mencoba export via TensorFlow...")
    
    try:
        import tensorflow as tf
        from onnx_tf.backend import prepare
        import onnx
        
        # ONNX → TF
        onnx_model = onnx.load(str(onnx_path))
        tf_rep = prepare(onnx_model)
        
        saved_model_path = str(MODELS_DIR / "tf_saved_model")
        tf_rep.export_graph(saved_model_path)
        
        # TF → TFLite
        converter = tf.lite.TFLiteConverter.from_saved_model(saved_model_path)
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        converter.target_spec.supported_types = [tf.float16]
        
        tflite_model = converter.convert()
        
        tflite_path = MODELS_DIR / "bisindo_model.tflite"
        with open(tflite_path, 'wb') as f:
            f.write(tflite_model)
        
        file_size = tflite_path.stat().st_size / (1024 * 1024)
        print(f"   ✅ TFLite model saved: {tflite_path}")
        print(f"   📏 Size: {file_size:.2f} MB")
        
        return tflite_path
        
    except ImportError:
        print("   ⚠️ TensorFlow/onnx-tf tidak tersedia")
        return None
    except Exception as e:
        print(f"   ⚠️ TF conversion error: {e}")
        return None


def export_tflite_manual(model):
    """Fallback: Export ke TorchScript + buat wrapper untuk TFLite inference."""
    print("\n📦 Fallback: Export ke TorchScript (.pt)...")
    
    model.eval()
    
    # Export TorchScript
    dummy_input = torch.randn(1, 3, IMAGE_SIZE, IMAGE_SIZE).to(DEVICE)
    traced_model = torch.jit.trace(model, dummy_input)
    
    torchscript_path = MODELS_DIR / "bisindo_model.pt"
    traced_model.save(str(torchscript_path))
    
    file_size = torchscript_path.stat().st_size / (1024 * 1024)
    print(f"   ✅ TorchScript model saved: {torchscript_path}")
    print(f"   📏 Size: {file_size:.2f} MB")
    
    # Juga export state dict untuk fleksibilitas
    state_dict_path = MODELS_DIR / "bisindo_model_weights.pth"
    torch.save(model.state_dict(), state_dict_path)
    print(f"   ✅ State dict saved: {state_dict_path}")
    
    return torchscript_path


# ============================================================
# VALIDASI MODEL
# ============================================================
def validate_exported_model(model_path, model_pytorch, class_names):
    """Validasi bahwa model yang diexport menghasilkan output yang sama."""
    print("\n🔍 Validating exported model...")
    
    # Generate test input
    test_input = torch.randn(1, 3, IMAGE_SIZE, IMAGE_SIZE).to(DEVICE)
    
    # PyTorch inference
    model_pytorch.eval()
    with torch.no_grad():
        pytorch_output = model_pytorch(test_input)
        pytorch_probs = torch.softmax(pytorch_output, dim=1)
        pytorch_pred = torch.argmax(pytorch_probs, dim=1).item()
    
    print(f"   PyTorch prediction: {class_names[pytorch_pred]} "
          f"(confidence: {pytorch_probs[0][pytorch_pred]:.4f})")
    
    # Validate based on format
    model_path = Path(model_path)
    
    if model_path.suffix == '.tflite':
        try:
            import tensorflow as tf
            interpreter = tf.lite.Interpreter(model_path=str(model_path))
            interpreter.allocate_tensors()
            
            input_details = interpreter.get_input_details()
            output_details = interpreter.get_output_details()
            
            # TFLite might expect NHWC format
            tflite_input = test_input.numpy()
            if input_details[0]['shape'][-1] == 3:  # NHWC
                tflite_input = np.transpose(tflite_input, (0, 2, 3, 1))
            
            interpreter.set_tensor(input_details[0]['index'], tflite_input.astype(np.float32))
            interpreter.invoke()
            
            tflite_output = interpreter.get_tensor(output_details[0]['index'])
            tflite_pred = np.argmax(tflite_output)
            
            print(f"   TFLite prediction: {class_names[tflite_pred]}")
            
            if pytorch_pred == tflite_pred:
                print("   ✅ Predictions match!")
            else:
                print("   ⚠️ Predictions differ (may be due to quantization)")
                
        except Exception as e:
            print(f"   ⚠️ TFLite validation skipped: {e}")
    
    elif model_path.suffix == '.onnx':
        try:
            import onnxruntime as ort
            session = ort.InferenceSession(str(model_path))
            onnx_output = session.run(None, {'input': test_input.numpy()})
            onnx_pred = np.argmax(onnx_output[0])
            
            print(f"   ONNX prediction: {class_names[onnx_pred]}")
            
            if pytorch_pred == onnx_pred:
                print("   ✅ Predictions match!")
            else:
                print("   ⚠️ Predictions differ")
                
        except Exception as e:
            print(f"   ⚠️ ONNX validation: {e}")
    
    elif model_path.suffix == '.pt':
        loaded = torch.jit.load(str(model_path))
        loaded.eval()
        with torch.no_grad():
            ts_output = loaded(test_input)
            ts_pred = torch.argmax(ts_output, dim=1).item()
        
        print(f"   TorchScript prediction: {class_names[ts_pred]}")
        
        if pytorch_pred == ts_pred:
            print("   ✅ Predictions match!")
        else:
            print("   ⚠️ Predictions differ")


# ============================================================
# COPY KE FLUTTER PROJECT
# ============================================================
def copy_to_flutter(model_path, class_names):
    """Copy model dan metadata ke Flutter project."""
    print("\n📱 Copying to Flutter project...")
    
    FLUTTER_MODELS_DIR.mkdir(parents=True, exist_ok=True)
    
    # Copy model file
    model_path = Path(model_path)
    dest_model = FLUTTER_MODELS_DIR / model_path.name
    shutil.copy2(model_path, dest_model)
    print(f"   ✅ Model copied: {dest_model}")
    
    # Also copy ONNX if exists (for alternative inference)
    onnx_path = MODELS_DIR / "bisindo_model.onnx"
    if onnx_path.exists():
        dest_onnx = FLUTTER_MODELS_DIR / "bisindo_model.onnx"
        shutil.copy2(onnx_path, dest_onnx)
        print(f"   ✅ ONNX model copied: {dest_onnx}")
    
    # Copy class labels
    labels_data = {
        "labels": class_names,
        "num_classes": len(class_names),
        "image_size": IMAGE_SIZE,
        "normalization": {
            "mean": [0.485, 0.456, 0.406],
            "std": [0.229, 0.224, 0.225]
        },
        "input_format": "RGB",
        "input_shape": [1, 3, IMAGE_SIZE, IMAGE_SIZE]
    }
    
    labels_path = FLUTTER_MODELS_DIR / "labels.json"
    with open(labels_path, "w") as f:
        json.dump(labels_data, f, indent=2)
    print(f"   ✅ Labels saved: {labels_path}")
    
    # Create a simple text labels file (for tflite_flutter)
    txt_labels_path = FLUTTER_MODELS_DIR / "labels.txt"
    with open(txt_labels_path, "w") as f:
        for name in class_names:
            f.write(f"{name}\n")
    print(f"   ✅ Text labels saved: {txt_labels_path}")


# ============================================================
# MAIN
# ============================================================
def main():
    print("=" * 60)
    print("  HANDTALK BISINDO - Export Model ke TFLite")
    print("=" * 60)
    
    # Step 1: Load model
    model, num_classes, class_names = load_trained_model()
    
    # Step 2: Export ke ONNX (intermediate format)
    onnx_path = export_to_onnx(model)
    
    # Step 3: Try multiple export paths to TFLite
    tflite_path = None
    
    # Method 1: ai_edge_torch (direct PyTorch → TFLite)
    tflite_path = export_tflite_via_torch(model, num_classes, class_names)
    
    # Method 2: ONNX → TF → TFLite
    if tflite_path is None:
        tflite_path = export_tflite_via_tf(onnx_path)
    
    # Method 3: Fallback to TorchScript
    if tflite_path is None:
        print("\n⚠️ TFLite conversion tidak berhasil.")
        print("   Menggunakan TorchScript sebagai fallback.")
        print("   Untuk TFLite, install: pip install tensorflow onnx-tf")
        print("   Atau: pip install ai-edge-torch")
        tflite_path = export_tflite_manual(model)
    
    # Step 4: Validate
    validate_exported_model(tflite_path, model, class_names)
    
    # Step 5: Copy to Flutter project
    copy_to_flutter(tflite_path, class_names)
    
    print("\n" + "=" * 60)
    print("  ✅ EXPORT SELESAI!")
    print("=" * 60)
    print(f"\n📁 Model files:")
    for f in MODELS_DIR.iterdir():
        if f.is_file():
            size = f.stat().st_size / (1024 * 1024)
            print(f"   {f.name} ({size:.2f} MB)")
    
    print(f"\n📱 Flutter assets:")
    for f in FLUTTER_MODELS_DIR.iterdir():
        if f.is_file() and f.name != '.gitkeep':
            size = f.stat().st_size / (1024 * 1024)
            print(f"   {f.name} ({size:.2f} MB)")
    
    print(f"\n➡️  Langkah selanjutnya:")
    print(f"   1. Jalankan 04_integrate_flutter.py untuk update kode Flutter")
    print(f"   2. Build dan test aplikasi di Android device")


if __name__ == "__main__":
    main()
