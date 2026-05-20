"""
Fix BISINDO model conversion: PyTorch -> ONNX -> validate with actual images.
Then create a proper TFLite model by re-training a TF model from scratch
using the same dataset.

Since onnx2tf has dependency issues, we'll use a different approach:
1. Validate the ONNX model works correctly
2. If ONNX works, the issue is in TFLite conversion
3. Create a fresh TF model trained on the same data
"""
import os, sys
os.environ['TF_ENABLE_ONEDNN_OPTS'] = '0'
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '3'

import numpy as np
from pathlib import Path
from PIL import Image

# Paths
DATASET_PATH = Path(r"C:\Users\User\.cache\kagglehub\datasets\sifaqeinstein\bisindo\versions\1\split\train\images")
MODELS_DIR = Path(r"C:\pcs_project\training\models")
FLUTTER_MODELS = Path(r"C:\pcs_project\handtalk\assets\models")

LABELS = list("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
IMG_SIZE = 224
MEAN = np.array([0.485, 0.456, 0.406])
STD = np.array([0.229, 0.224, 0.225])


def preprocess_image(img_path):
    """Preprocess image same as training."""
    img = Image.open(img_path).convert('RGB').resize((IMG_SIZE, IMG_SIZE))
    arr = np.array(img, dtype=np.float32) / 255.0
    arr = (arr - MEAN) / STD
    return arr


def test_onnx_model():
    """Test ONNX model accuracy with dataset images."""
    import onnxruntime as ort
    
    onnx_path = str(MODELS_DIR / "bisindo_model.onnx")
    if not os.path.exists(onnx_path):
        # Try flutter assets
        onnx_path = str(FLUTTER_MODELS / "bisindo_model.onnx")
    
    print(f"Loading ONNX model: {onnx_path}")
    session = ort.InferenceSession(onnx_path)
    
    input_name = session.get_inputs()[0].name
    input_shape = session.get_inputs()[0].shape
    print(f"  Input: {input_name}, shape: {input_shape}")
    print(f"  Output: {session.get_outputs()[0].name}, shape: {session.get_outputs()[0].shape}")
    
    # Test with images from each letter
    correct = 0
    total = 0
    errors = []
    
    for letter in LABELS:
        folder = DATASET_PATH / letter
        if not folder.exists():
            continue
        
        images = sorted(folder.glob("*.jpg"))[:3]  # Test 3 per letter
        
        for img_path in images:
            arr = preprocess_image(img_path)
            
            # ONNX expects NCHW: [1, 3, 224, 224]
            arr_nchw = np.transpose(arr, (2, 0, 1))  # HWC -> CHW
            arr_nchw = np.expand_dims(arr_nchw, 0).astype(np.float32)
            
            output = session.run(None, {input_name: arr_nchw})[0]
            
            # Softmax
            exp_v = np.exp(output[0] - np.max(output[0]))
            probs = exp_v / exp_v.sum()
            pred_idx = np.argmax(probs)
            pred_letter = LABELS[pred_idx]
            conf = probs[pred_idx]
            
            total += 1
            if pred_letter == letter:
                correct += 1
            else:
                errors.append(f"  {letter} -> {pred_letter} ({conf*100:.1f}%) [{img_path.name}]")
    
    acc = correct / total * 100 if total > 0 else 0
    print(f"\nONNX Model Accuracy: {correct}/{total} = {acc:.1f}%")
    
    if errors:
        print(f"\nErrors ({len(errors)}):")
        for e in errors[:10]:
            print(e)
    
    return acc > 90  # ONNX should be accurate


def create_proper_tflite():
    """
    Create proper TFLite by:
    1. Loading PyTorch model
    2. Running inference on dataset to get feature vectors
    3. Training a simple TF model on those features
    4. Converting to TFLite
    
    OR simpler: just train a TF MobileNetV2 from scratch on the dataset.
    """
    import tensorflow as tf
    
    print("\n" + "="*55)
    print("  Training fresh TF model on BISINDO dataset")
    print("="*55)
    
    # Load dataset
    print("\nLoading dataset...")
    train_images = []
    train_labels = []
    
    for idx, letter in enumerate(LABELS):
        folder = DATASET_PATH / letter
        if not folder.exists():
            continue
        
        images = sorted(folder.glob("*.jpg"))
        # Use subset for faster training (80 per class)
        for img_path in images[:80]:
            arr = preprocess_image(img_path)
            train_images.append(arr)
            train_labels.append(idx)
    
    X = np.array(train_images, dtype=np.float32)
    y = np.array(train_labels, dtype=np.int32)
    
    print(f"  Dataset: {X.shape[0]} images, {len(LABELS)} classes")
    print(f"  Shape: {X.shape}")
    
    # Shuffle
    perm = np.random.permutation(len(X))
    X, y = X[perm], y[perm]
    
    # Split train/val
    split = int(0.85 * len(X))
    X_train, X_val = X[:split], X[split:]
    y_train, y_val = y[:split], y[split:]
    
    print(f"  Train: {len(X_train)}, Val: {len(X_val)}")
    
    # Create model
    print("\nCreating MobileNetV2 model...")
    base_model = tf.keras.applications.MobileNetV2(
        input_shape=(IMG_SIZE, IMG_SIZE, 3),
        include_top=False,
        weights='imagenet',
        pooling='avg'
    )
    
    # Freeze base initially
    base_model.trainable = False
    
    model = tf.keras.Sequential([
        base_model,
        tf.keras.layers.Dropout(0.3),
        tf.keras.layers.Dense(256, activation='relu'),
        tf.keras.layers.Dropout(0.2),
        tf.keras.layers.Dense(26, activation='softmax')
    ])
    
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=0.001),
        loss='sparse_categorical_crossentropy',
        metrics=['accuracy']
    )
    
    # Train classifier head first
    print("\nPhase 1: Training classifier (base frozen)...")
    model.fit(
        X_train, y_train,
        validation_data=(X_val, y_val),
        epochs=5,
        batch_size=32,
        verbose=1
    )
    
    # Fine-tune: unfreeze last 30 layers
    print("\nPhase 2: Fine-tuning (last 30 layers unfrozen)...")
    base_model.trainable = True
    for layer in base_model.layers[:-30]:
        layer.trainable = False
    
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=0.0001),
        loss='sparse_categorical_crossentropy',
        metrics=['accuracy']
    )
    
    model.fit(
        X_train, y_train,
        validation_data=(X_val, y_val),
        epochs=10,
        batch_size=32,
        verbose=1
    )
    
    # Evaluate
    val_loss, val_acc = model.evaluate(X_val, y_val, verbose=0)
    print(f"\nFinal validation accuracy: {val_acc*100:.1f}%")
    
    # Convert to TFLite
    print("\nConverting to TFLite...")
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.target_spec.supported_types = [tf.float16]
    
    tflite_model = converter.convert()
    
    tflite_path = FLUTTER_MODELS / "bisindo_model.tflite"
    with open(tflite_path, 'wb') as f:
        f.write(tflite_model)
    
    size_mb = tflite_path.stat().st_size / (1024 * 1024)
    print(f"  Saved: {tflite_path} ({size_mb:.2f} MB)")
    
    # Update labels.json
    import json
    metadata = {
        "labels": LABELS,
        "num_classes": 26,
        "image_size": IMG_SIZE,
        "normalization": {"mean": MEAN.tolist(), "std": STD.tolist()},
        "input_format": "NHWC",
        "input_shape": [1, IMG_SIZE, IMG_SIZE, 3],
        "val_accuracy": float(val_acc),
        "model_architecture": "MobileNetV2 + Custom Classifier (TF native)",
        "quantization": "float16"
    }
    
    with open(FLUTTER_MODELS / "labels.json", "w") as f:
        json.dump(metadata, f, indent=2)
    
    print("  labels.json updated!")
    
    # Validate TFLite
    print("\nValidating TFLite model...")
    interp = tf.lite.Interpreter(model_path=str(tflite_path))
    interp.allocate_tensors()
    
    inp_details = interp.get_input_details()
    out_details = interp.get_output_details()
    print(f"  Input: {inp_details[0]['shape']}")
    print(f"  Output: {out_details[0]['shape']}")
    
    # Test with dataset images
    correct = 0
    total = 0
    for idx, letter in enumerate(LABELS):
        folder = DATASET_PATH / letter
        images = sorted(folder.glob("*.jpg"))[:2]
        for img_path in images:
            arr = preprocess_image(img_path)
            arr = np.expand_dims(arr, 0).astype(np.float32)
            
            interp.set_tensor(inp_details[0]['index'], arr)
            interp.invoke()
            output = interp.get_tensor(out_details[0]['index'])
            
            pred_idx = np.argmax(output[0])
            total += 1
            if LABELS[pred_idx] == letter:
                correct += 1
    
    tflite_acc = correct / total * 100
    print(f"  TFLite accuracy: {correct}/{total} = {tflite_acc:.1f}%")
    
    return val_acc


def main():
    print("="*55)
    print("  BISINDO Model Fix - Proper TFLite Conversion")
    print("="*55)
    
    # Step 1: Test ONNX model
    print("\n--- Step 1: Validate ONNX model ---")
    onnx_ok = test_onnx_model()
    
    if onnx_ok:
        print("\nONNX model is accurate! Issue is in TFLite conversion.")
    else:
        print("\nONNX model also has issues. Will retrain from scratch.")
    
    # Step 2: Create proper TFLite (train fresh TF model)
    print("\n--- Step 2: Create proper TFLite model ---")
    create_proper_tflite()
    
    print("\n" + "="*55)
    print("  DONE! New TFLite model saved to Flutter assets.")
    print("="*55)


if __name__ == "__main__":
    main()
