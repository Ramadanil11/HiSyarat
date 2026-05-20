"""Quick test: validate ONNX model with dataset images."""
import os, sys
import numpy as np
from pathlib import Path
from PIL import Image
import onnxruntime as ort

DATASET_PATH = Path(r"C:\Users\User\.cache\kagglehub\datasets\sifaqeinstein\bisindo\versions\1\split\train\images")
MODELS_DIR = Path(r"C:\pcs_project\training\models")
FLUTTER_MODELS = Path(r"C:\pcs_project\handtalk\assets\models")
LABELS = list("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
MEAN = np.array([0.485, 0.456, 0.406])
STD = np.array([0.229, 0.224, 0.225])

def preprocess(img_path):
    img = Image.open(img_path).convert('RGB').resize((224, 224))
    arr = np.array(img, dtype=np.float32) / 255.0
    arr = (arr - MEAN) / STD
    return arr

# Load ONNX
onnx_path = str(MODELS_DIR / "bisindo_model.onnx")
if not os.path.exists(onnx_path):
    onnx_path = str(FLUTTER_MODELS / "bisindo_model.onnx")
print(f"ONNX: {onnx_path}")

session = ort.InferenceSession(onnx_path)
input_name = session.get_inputs()[0].name
input_shape = session.get_inputs()[0].shape
print(f"Input: {input_name}, shape: {input_shape}")

correct = 0
total = 0
wrong = []

for letter in LABELS:
    folder = DATASET_PATH / letter
    if not folder.exists():
        continue
    images = sorted(folder.glob("*.jpg"))[:2]
    for img_path in images:
        arr = preprocess(img_path)
        # PyTorch ONNX expects NCHW
        arr_nchw = np.transpose(arr, (2, 0, 1))
        arr_nchw = np.expand_dims(arr_nchw, 0).astype(np.float32)
        
        output = session.run(None, {input_name: arr_nchw})[0]
        exp_v = np.exp(output[0] - np.max(output[0]))
        probs = exp_v / exp_v.sum()
        pred_idx = np.argmax(probs)
        pred = LABELS[pred_idx]
        conf = probs[pred_idx]
        
        total += 1
        if pred == letter:
            correct += 1
        else:
            wrong.append(f"{letter}->{pred}({conf*100:.0f}%)")

print(f"\nAccuracy: {correct}/{total} = {correct/total*100:.1f}%")
if wrong:
    print(f"Wrong ({len(wrong)}): {', '.join(wrong[:15])}")
