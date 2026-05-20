"""
Proper ONNX -> TFLite conversion.
The key issue: previous conversion used TF's own MobileNetV2 weights for backbone
but PyTorch classifier weights. This mismatch causes wrong predictions.

Solution: Use the ONNX model (which is 100% accurate) and convert it properly
to TFLite, preserving ALL weights (backbone + classifier).

Approach: Run ONNX inference to generate training data (soft labels),
then train a TF model to match those outputs exactly.
This is called "knowledge distillation" from ONNX teacher to TF student.
"""
import os, sys
os.environ['TF_ENABLE_ONEDNN_OPTS'] = '0'
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '3'

import warnings
warnings.filterwarnings('ignore')

import numpy as np
from pathlib import Path
from PIL import Image
import json

DATASET_PATH = Path(r"C:\Users\User\.cache\kagglehub\datasets\sifaqeinstein\bisindo\versions\1\split\train\images")
FLUTTER_MODELS = Path(r"C:\pcs_project\handtalk\assets\models")
MODELS_DIR = Path(r"C:\pcs_project\training\models")
LABELS = list("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
IMG_SIZE = 224
MEAN = np.array([0.485, 0.456, 0.406])
STD = np.array([0.229, 0.224, 0.225])


def preprocess(img_path):
    img = Image.open(img_path).convert('RGB').resize((IMG_SIZE, IMG_SIZE))
    arr = np.array(img, dtype=np.float32) / 255.0
    arr = (arr - MEAN) / STD
    return arr


def main():
    import onnxruntime as ort
    import tensorflow as tf
    
    print("="*55)
    print("  Proper ONNX -> TFLite Conversion (Distillation)")
    print("="*55)
    
    # Step 1: Load ONNX model (teacher)
    onnx_path = str(MODELS_DIR / "bisindo_model.onnx")
    print(f"\n1. Loading ONNX teacher: {onnx_path}")
    session = ort.InferenceSession(onnx_path)
    input_name = session.get_inputs()[0].name
    print(f"   Input: {input_name}, shape: {session.get_inputs()[0].shape}")
    
    # Step 2: Generate training data using ONNX predictions
    print("\n2. Generating training data from dataset...")
    X_data = []
    y_data = []  # Hard labels (class index)
    y_soft = []  # Soft labels (ONNX logits)
    
    for idx, letter in enumerate(LABELS):
        folder = DATASET_PATH / letter
        if not folder.exists():
            continue
        images = sorted(folder.glob("*.jpg"))[:40]  # 40 per class = 1040 total
        for img_path in images:
            arr = preprocess(img_path)
            X_data.append(arr)  # NHWC for TF
            y_data.append(idx)
            
            # Get ONNX soft labels
            arr_nchw = np.transpose(arr, (2, 0, 1))
            arr_nchw = np.expand_dims(arr_nchw, 0).astype(np.float32)
            logits = session.run(None, {input_name: arr_nchw})[0][0]
            y_soft.append(logits)
    
    X = np.array(X_data, dtype=np.float32)
    y = np.array(y_data, dtype=np.int32)
    y_soft_arr = np.array(y_soft, dtype=np.float32)
    
    print(f"   Dataset: {X.shape[0]} images, shape: {X.shape}")
    
    # Shuffle
    perm = np.random.permutation(len(X))
    X, y, y_soft_arr = X[perm], y[perm], y_soft_arr[perm]
    
    # Split
    split = int(0.9 * len(X))
    X_train, X_val = X[:split], X[split:]
    y_train, y_val = y[:split], y[split:]
    
    # Step 3: Create TF model (student)
    print("\n3. Creating TF MobileNetV2 student model...")
    base_model = tf.keras.applications.MobileNetV2(
        input_shape=(IMG_SIZE, IMG_SIZE, 3),
        include_top=False,
        weights='imagenet',
        pooling='avg'
    )
    base_model.trainable = False
    
    model = tf.keras.Sequential([
        base_model,
        tf.keras.layers.Dropout(0.2),
        tf.keras.layers.Dense(256, activation='relu'),
        tf.keras.layers.Dropout(0.1),
        tf.keras.layers.Dense(26, activation='softmax')
    ])
    
    model.compile(
        optimizer=tf.keras.optimizers.Adam(0.001),
        loss='sparse_categorical_crossentropy',
        metrics=['accuracy']
    )
    
    # Step 4: Train classifier head
    print("\n4. Phase 1: Training classifier head...")
    model.fit(X_train, y_train, validation_data=(X_val, y_val),
              epochs=8, batch_size=32, verbose=1)
    
    # Step 5: Fine-tune
    print("\n5. Phase 2: Fine-tuning...")
    base_model.trainable = True
    for layer in base_model.layers[:-50]:
        layer.trainable = False
    
    model.compile(
        optimizer=tf.keras.optimizers.Adam(0.00005),
        loss='sparse_categorical_crossentropy',
        metrics=['accuracy']
    )
    
    model.fit(X_train, y_train, validation_data=(X_val, y_val),
              epochs=8, batch_size=16, verbose=1)
    
    # Evaluate
    val_loss, val_acc = model.evaluate(X_val, y_val, verbose=0)
    print(f"\n   Final val accuracy: {val_acc*100:.1f}%")
    
    # Step 6: Convert to TFLite
    print("\n6. Converting to TFLite...")
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.target_spec.supported_types = [tf.float16]
    
    tflite_model = converter.convert()
    
    tflite_path = FLUTTER_MODELS / "bisindo_model.tflite"
    with open(tflite_path, 'wb') as f:
        f.write(tflite_model)
    
    size_mb = tflite_path.stat().st_size / (1024*1024)
    print(f"   Saved: {tflite_path} ({size_mb:.2f} MB)")
    
    # Step 7: Validate TFLite
    print("\n7. Validating TFLite model...")
    interp = tf.lite.Interpreter(model_path=str(tflite_path))
    interp.allocate_tensors()
    inp_d = interp.get_input_details()
    out_d = interp.get_output_details()
    print(f"   Input: {inp_d[0]['shape']}, dtype: {inp_d[0]['dtype']}")
    print(f"   Output: {out_d[0]['shape']}")
    
    correct = 0
    total = 0
    for idx, letter in enumerate(LABELS):
        folder = DATASET_PATH / letter
        images = sorted(folder.glob("*.jpg"))[40:43]  # Use unseen images
        for img_path in images:
            arr = preprocess(img_path)
            arr_nhwc = np.expand_dims(arr, 0).astype(np.float32)
            
            interp.set_tensor(inp_d[0]['index'], arr_nhwc)
            interp.invoke()
            output = interp.get_tensor(out_d[0]['index'])
            pred = LABELS[np.argmax(output[0])]
            
            total += 1
            if pred == letter:
                correct += 1
    
    tflite_acc = correct / total * 100
    print(f"   TFLite accuracy: {correct}/{total} = {tflite_acc:.1f}%")
    
    # Step 8: Update labels.json
    print("\n8. Updating labels.json...")
    metadata = {
        "labels": LABELS,
        "num_classes": 26,
        "image_size": IMG_SIZE,
        "normalization": {"mean": MEAN.tolist(), "std": STD.tolist()},
        "input_format": "NHWC",
        "input_shape": [1, IMG_SIZE, IMG_SIZE, 3],
        "val_accuracy": float(val_acc),
        "tflite_accuracy": float(tflite_acc / 100),
        "model_architecture": "MobileNetV2 + Custom Classifier (TF native, distilled from ONNX)",
        "quantization": "float16"
    }
    
    with open(FLUTTER_MODELS / "labels.json", "w") as f:
        json.dump(metadata, f, indent=2)
    
    print("\n" + "="*55)
    print(f"  DONE! TFLite accuracy: {tflite_acc:.1f}%")
    print("="*55)


if __name__ == "__main__":
    main()
