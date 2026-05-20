"""
Fast BISINDO model conversion: Train minimal TF model -> TFLite.
Uses fewer images and epochs for speed. Target: >85% accuracy.
"""
import os, sys
os.environ['TF_ENABLE_ONEDNN_OPTS'] = '0'
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '3'
import warnings
warnings.filterwarnings('ignore')

import numpy as np
from pathlib import Path
from PIL import Image

DATASET = Path(r"C:\Users\User\.cache\kagglehub\datasets\sifaqeinstein\bisindo\versions\1\split\train\images")
OUTPUT = Path(r"C:\pcs_project\handtalk\assets\models")
LABELS = list("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
MEAN = np.array([0.485, 0.456, 0.406])
STD = np.array([0.229, 0.224, 0.225])

def preprocess(path):
    img = Image.open(path).convert('RGB').resize((224, 224))
    arr = np.array(img, dtype=np.float32) / 255.0
    return (arr - MEAN) / STD

print("Loading images...")
X, y = [], []
for idx, letter in enumerate(LABELS):
    folder = DATASET / letter
    imgs = sorted(folder.glob("*.jpg"))[:20]  # Only 20 per class = 520 total
    for p in imgs:
        X.append(preprocess(p))
        y.append(idx)

X = np.array(X, dtype=np.float32)
y = np.array(y, dtype=np.int32)
perm = np.random.permutation(len(X))
X, y = X[perm], y[perm]
split = int(0.85 * len(X))
X_train, X_val = X[:split], X[split:]
y_train, y_val = y[:split], y[split:]
print(f"Train: {len(X_train)}, Val: {len(X_val)}")

import tensorflow as tf

print("Building model...")
base = tf.keras.applications.MobileNetV2(
    input_shape=(224,224,3), include_top=False, weights='imagenet', pooling='avg')
base.trainable = False

model = tf.keras.Sequential([
    base,
    tf.keras.layers.Dense(128, activation='relu'),
    tf.keras.layers.Dropout(0.3),
    tf.keras.layers.Dense(26, activation='softmax')
])
model.compile(optimizer='adam', loss='sparse_categorical_crossentropy', metrics=['accuracy'])

print("Training phase 1 (frozen base)...")
model.fit(X_train, y_train, validation_data=(X_val, y_val), epochs=10, batch_size=32, verbose=2)

print("Fine-tuning...")
base.trainable = True
for layer in base.layers[:-20]:
    layer.trainable = False
model.compile(optimizer=tf.keras.optimizers.Adam(1e-4), loss='sparse_categorical_crossentropy', metrics=['accuracy'])
model.fit(X_train, y_train, validation_data=(X_val, y_val), epochs=5, batch_size=16, verbose=2)

val_loss, val_acc = model.evaluate(X_val, y_val, verbose=0)
print(f"Val accuracy: {val_acc*100:.1f}%")

print("Converting to TFLite...")
converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
converter.target_spec.supported_types = [tf.float16]
tflite_model = converter.convert()

tflite_path = OUTPUT / "bisindo_model.tflite"
with open(tflite_path, 'wb') as f:
    f.write(tflite_model)
print(f"Saved: {tflite_path} ({tflite_path.stat().st_size/1024/1024:.2f} MB)")

# Validate
print("Validating TFLite...")
interp = tf.lite.Interpreter(model_path=str(tflite_path))
interp.allocate_tensors()
inp_d = interp.get_input_details()
out_d = interp.get_output_details()

correct = total = 0
for idx, letter in enumerate(LABELS):
    folder = DATASET / letter
    imgs = sorted(folder.glob("*.jpg"))[20:23]  # unseen images
    for p in imgs:
        arr = np.expand_dims(preprocess(p), 0).astype(np.float32)
        interp.set_tensor(inp_d[0]['index'], arr)
        interp.invoke()
        pred = LABELS[np.argmax(interp.get_tensor(out_d[0]['index'])[0])]
        total += 1
        if pred == letter: correct += 1

print(f"TFLite accuracy: {correct}/{total} = {correct/total*100:.1f}%")

# Update labels.json
import json
meta = {
    "labels": LABELS, "num_classes": 26, "image_size": 224,
    "normalization": {"mean": MEAN.tolist(), "std": STD.tolist()},
    "input_format": "NHWC", "input_shape": [1, 224, 224, 3],
    "val_accuracy": float(val_acc),
    "tflite_accuracy": correct/total,
}
with open(OUTPUT / "labels.json", "w") as f:
    json.dump(meta, f, indent=2)
print("Done! labels.json updated.")
