"""
=============================================================
HandTalk BISINDO - Step 2: Training Model Deep Learning
=============================================================
Script ini melakukan:
1. Load & preprocessing dataset BISINDO
2. Data augmentation
3. Training MobileNetV2 (transfer learning)
4. Evaluasi model (confusion matrix, classification report)
5. Export model terbaik

Arsitektur: MobileNetV2 (pretrained ImageNet) + Custom Classifier
=============================================================
"""

import os
import sys
import io
import json
import time
import copy

# Fix Windows console encoding for emoji/unicode
if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')
import numpy as np
import matplotlib
matplotlib.use('Agg')  # Non-interactive backend
import matplotlib.pyplot as plt
import seaborn as sns
from pathlib import Path
from datetime import datetime

import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, Dataset, random_split
from torchvision import transforms, models
from PIL import Image
from sklearn.metrics import classification_report, confusion_matrix
from tqdm import tqdm

# ============================================================
# KONFIGURASI
# ============================================================
class Config:
    # Dataset
    IMAGE_SIZE = 224          # Input size untuk MobileNetV2
    BATCH_SIZE = 32
    NUM_WORKERS = 0           # Windows compatibility
    TRAIN_RATIO = 0.8
    VAL_RATIO = 0.1
    TEST_RATIO = 0.1
    
    # Training
    NUM_EPOCHS = 30
    LEARNING_RATE = 0.001
    WEIGHT_DECAY = 1e-4
    LR_STEP_SIZE = 7
    LR_GAMMA = 0.1
    EARLY_STOPPING_PATIENCE = 7
    
    # Model
    MODEL_NAME = "mobilenet_v2"
    FREEZE_BACKBONE = True     # Freeze pretrained layers awalnya
    UNFREEZE_EPOCH = 10        # Unfreeze setelah epoch ke-10 untuk fine-tuning
    
    # Paths
    BASE_DIR = Path(__file__).parent
    MODELS_DIR = BASE_DIR / "models"
    LOGS_DIR = BASE_DIR / "logs"
    
    # Device
    DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")


# ============================================================
# DATASET CLASS
# ============================================================
class BISINDODataset(Dataset):
    """Custom Dataset untuk gambar BISINDO."""
    
    def __init__(self, image_paths, labels, transform=None):
        self.image_paths = image_paths
        self.labels = labels
        self.transform = transform
    
    def __len__(self):
        return len(self.image_paths)
    
    def __getitem__(self, idx):
        img_path = self.image_paths[idx]
        label = self.labels[idx]
        
        # Load gambar
        try:
            image = Image.open(img_path).convert("RGB")
        except Exception as e:
            print(f"⚠️ Error loading {img_path}: {e}")
            # Return black image sebagai fallback
            image = Image.new("RGB", (Config.IMAGE_SIZE, Config.IMAGE_SIZE), (0, 0, 0))
        
        if self.transform:
            image = self.transform(image)
        
        return image, label


# ============================================================
# DATA TRANSFORMS (AUGMENTASI)
# ============================================================
def get_transforms():
    """Definisikan transformasi untuk train, val, dan test."""
    
    # Training: augmentasi agresif untuk robustness
    train_transform = transforms.Compose([
        transforms.Resize((Config.IMAGE_SIZE + 32, Config.IMAGE_SIZE + 32)),
        transforms.RandomCrop(Config.IMAGE_SIZE),
        transforms.RandomHorizontalFlip(p=0.3),  # Hati-hati dengan flip untuk sign language
        transforms.RandomRotation(15),
        transforms.ColorJitter(
            brightness=0.3,
            contrast=0.3,
            saturation=0.2,
            hue=0.1
        ),
        transforms.RandomAffine(
            degrees=0,
            translate=(0.1, 0.1),
            scale=(0.9, 1.1)
        ),
        transforms.RandomPerspective(distortion_scale=0.2, p=0.3),
        transforms.ToTensor(),
        transforms.Normalize(
            mean=[0.485, 0.456, 0.406],  # ImageNet normalization
            std=[0.229, 0.224, 0.225]
        ),
        transforms.RandomErasing(p=0.2),  # Cutout augmentation
    ])
    
    # Validation & Test: hanya resize dan normalize
    val_transform = transforms.Compose([
        transforms.Resize((Config.IMAGE_SIZE, Config.IMAGE_SIZE)),
        transforms.ToTensor(),
        transforms.Normalize(
            mean=[0.485, 0.456, 0.406],
            std=[0.229, 0.224, 0.225]
        ),
    ])
    
    return train_transform, val_transform


# ============================================================
# LOAD DATASET
# ============================================================
def load_dataset(dataset_path):
    """Load semua gambar dan label dari dataset."""
    print("\n📂 Loading dataset...")
    
    dataset_path = Path(dataset_path)
    image_extensions = {'.jpg', '.jpeg', '.png', '.bmp', '.gif', '.webp'}
    
    image_paths = []
    labels = []
    class_names = []
    
    # Scan semua subfolder sebagai kelas
    class_dirs = sorted([d for d in dataset_path.rglob("*") if d.is_dir()])
    
    # Filter: hanya folder yang berisi gambar
    valid_class_dirs = []
    for d in class_dirs:
        imgs = [f for f in d.iterdir() if f.is_file() and f.suffix.lower() in image_extensions]
        if imgs:
            valid_class_dirs.append(d)
    
    if not valid_class_dirs:
        # Mungkin gambar langsung di root folder, cek parent folders
        print("   Mencari struktur dataset...")
        for item in dataset_path.iterdir():
            if item.is_dir():
                for sub in item.rglob("*"):
                    if sub.is_dir():
                        imgs = [f for f in sub.iterdir() if f.is_file() and f.suffix.lower() in image_extensions]
                        if imgs:
                            valid_class_dirs.append(sub)
    
    print(f"   Ditemukan {len(valid_class_dirs)} folder kelas")
    
    # Buat mapping kelas
    class_names = sorted(list(set(d.name for d in valid_class_dirs)))
    class_to_idx = {name: idx for idx, name in enumerate(class_names)}
    
    print(f"   Kelas: {class_names}")
    
    # Load semua gambar
    for class_dir in valid_class_dirs:
        class_name = class_dir.name
        class_idx = class_to_idx[class_name]
        
        for img_file in class_dir.iterdir():
            if img_file.is_file() and img_file.suffix.lower() in image_extensions:
                image_paths.append(str(img_file))
                labels.append(class_idx)
    
    print(f"   Total gambar: {len(image_paths)}")
    print(f"   Total kelas: {len(class_names)}")
    
    return image_paths, labels, class_names, class_to_idx


def split_dataset(image_paths, labels, class_names):
    """Split dataset menjadi train/val/test."""
    print("\n✂️  Splitting dataset...")
    
    # Stratified split
    from sklearn.model_selection import train_test_split
    
    # Split: train+val vs test
    train_val_paths, test_paths, train_val_labels, test_labels = train_test_split(
        image_paths, labels,
        test_size=Config.TEST_RATIO,
        stratify=labels,
        random_state=42
    )
    
    # Split: train vs val
    val_ratio_adjusted = Config.VAL_RATIO / (Config.TRAIN_RATIO + Config.VAL_RATIO)
    train_paths, val_paths, train_labels, val_labels = train_test_split(
        train_val_paths, train_val_labels,
        test_size=val_ratio_adjusted,
        stratify=train_val_labels,
        random_state=42
    )
    
    print(f"   Train: {len(train_paths)} gambar")
    print(f"   Val:   {len(val_paths)} gambar")
    print(f"   Test:  {len(test_paths)} gambar")
    
    return (train_paths, train_labels), (val_paths, val_labels), (test_paths, test_labels)


# ============================================================
# MODEL
# ============================================================
def create_model(num_classes):
    """Buat model MobileNetV2 dengan custom classifier."""
    print(f"\n🧠 Membuat model {Config.MODEL_NAME}...")
    print(f"   Jumlah kelas: {num_classes}")
    print(f"   Device: {Config.DEVICE}")
    
    # Load pretrained MobileNetV2
    model = models.mobilenet_v2(weights=models.MobileNet_V2_Weights.IMAGENET1K_V1)
    
    # Freeze backbone layers
    if Config.FREEZE_BACKBONE:
        for param in model.features.parameters():
            param.requires_grad = False
        print("   ❄️  Backbone layers di-freeze")
    
    # Ganti classifier head
    num_features = model.classifier[1].in_features
    model.classifier = nn.Sequential(
        nn.Dropout(p=0.3),
        nn.Linear(num_features, 256),
        nn.ReLU(),
        nn.Dropout(p=0.2),
        nn.Linear(256, num_classes)
    )
    
    model = model.to(Config.DEVICE)
    
    # Hitung parameter
    total_params = sum(p.numel() for p in model.parameters())
    trainable_params = sum(p.numel() for p in model.parameters() if p.requires_grad)
    print(f"   Total parameters: {total_params:,}")
    print(f"   Trainable parameters: {trainable_params:,}")
    
    return model


# ============================================================
# TRAINING LOOP
# ============================================================
def train_model(model, train_loader, val_loader, num_classes, class_names):
    """Training loop dengan early stopping, LR scheduling, dan resume support."""
    print("\n" + "=" * 60)
    print("  🏋️  MULAI TRAINING")
    print("=" * 60)
    
    criterion = nn.CrossEntropyLoss()
    
    # Optimizer: hanya parameter yang trainable
    optimizer = optim.Adam(
        filter(lambda p: p.requires_grad, model.parameters()),
        lr=Config.LEARNING_RATE,
        weight_decay=Config.WEIGHT_DECAY
    )
    
    scheduler = optim.lr_scheduler.StepLR(
        optimizer,
        step_size=Config.LR_STEP_SIZE,
        gamma=Config.LR_GAMMA
    )
    
    # Tracking
    best_val_acc = 0.0
    best_model_wts = copy.deepcopy(model.state_dict())
    patience_counter = 0
    start_epoch = 0
    history = {
        'train_loss': [], 'train_acc': [],
        'val_loss': [], 'val_acc': [],
        'lr': []
    }
    
    # ---- RESUME FROM CHECKPOINT ----
    checkpoint_path = Config.MODELS_DIR / "training_checkpoint.pth"
    if checkpoint_path.exists():
        print(f"\n🔄 Resuming from checkpoint: {checkpoint_path}")
        ckpt = torch.load(checkpoint_path, map_location=Config.DEVICE, weights_only=False)
        model.load_state_dict(ckpt['model_state_dict'])
        try:
            optimizer.load_state_dict(ckpt['optimizer_state_dict'])
        except (ValueError, RuntimeError) as e:
            print(f"   WARNING: Could not load optimizer state ({e}), using fresh optimizer")
        try:
            scheduler.load_state_dict(ckpt['scheduler_state_dict'])
        except (ValueError, RuntimeError, KeyError) as e:
            print(f"   WARNING: Could not load scheduler state ({e}), using fresh scheduler")
        start_epoch = ckpt['epoch'] + 1
        best_val_acc = ckpt['best_val_acc']
        best_model_wts = copy.deepcopy(model.state_dict())
        patience_counter = ckpt.get('patience_counter', 0)
        history = ckpt.get('history', history)
        print(f"   Resumed at epoch {start_epoch + 1}, best_val_acc={best_val_acc:.4f}")
        
        # If we already unfroze backbone before, ensure it stays unfrozen
        if start_epoch >= Config.UNFREEZE_EPOCH and Config.FREEZE_BACKBONE:
            for param in model.features.parameters():
                param.requires_grad = True
    
    start_time = time.time()
    
    for epoch in range(start_epoch, Config.NUM_EPOCHS):
        epoch_start = time.time()
        
        # Unfreeze backbone setelah epoch tertentu
        if epoch == Config.UNFREEZE_EPOCH and Config.FREEZE_BACKBONE:
            print(f"\n🔓 Epoch {epoch}: Unfreeze backbone untuk fine-tuning!")
            for param in model.features.parameters():
                param.requires_grad = True
            
            # Reset optimizer dengan LR lebih kecil untuk fine-tuning
            optimizer = optim.Adam(
                model.parameters(),
                lr=Config.LEARNING_RATE * 0.1,
                weight_decay=Config.WEIGHT_DECAY
            )
            scheduler = optim.lr_scheduler.StepLR(
                optimizer, step_size=5, gamma=Config.LR_GAMMA
            )
        
        # ---- TRAINING PHASE ----
        model.train()
        running_loss = 0.0
        running_corrects = 0
        total_samples = 0
        
        train_pbar = tqdm(train_loader, desc=f"Epoch {epoch+1}/{Config.NUM_EPOCHS} [Train]",
                         leave=False, ncols=100)
        
        for inputs, labels in train_pbar:
            inputs = inputs.to(Config.DEVICE)
            labels = labels.to(Config.DEVICE)
            
            optimizer.zero_grad()
            
            outputs = model(inputs)
            loss = criterion(outputs, labels)
            _, preds = torch.max(outputs, 1)
            
            loss.backward()
            optimizer.step()
            
            running_loss += loss.item() * inputs.size(0)
            running_corrects += torch.sum(preds == labels.data)
            total_samples += inputs.size(0)
            
            # Update progress bar
            current_acc = running_corrects.double() / total_samples
            train_pbar.set_postfix({
                'loss': f'{loss.item():.4f}',
                'acc': f'{current_acc:.4f}'
            })
        
        train_loss = running_loss / total_samples
        train_acc = running_corrects.double() / total_samples
        
        # ---- VALIDATION PHASE ----
        model.eval()
        running_loss = 0.0
        running_corrects = 0
        total_samples = 0
        
        with torch.no_grad():
            for inputs, labels in val_loader:
                inputs = inputs.to(Config.DEVICE)
                labels = labels.to(Config.DEVICE)
                
                outputs = model(inputs)
                loss = criterion(outputs, labels)
                _, preds = torch.max(outputs, 1)
                
                running_loss += loss.item() * inputs.size(0)
                running_corrects += torch.sum(preds == labels.data)
                total_samples += inputs.size(0)
        
        val_loss = running_loss / total_samples
        val_acc = running_corrects.double() / total_samples
        
        # Update scheduler
        scheduler.step()
        current_lr = optimizer.param_groups[0]['lr']
        
        # Save history
        history['train_loss'].append(train_loss)
        history['train_acc'].append(train_acc.item())
        history['val_loss'].append(val_loss)
        history['val_acc'].append(val_acc.item())
        history['lr'].append(current_lr)
        
        epoch_time = time.time() - epoch_start
        
        # Print epoch results
        print(f"\nEpoch {epoch+1}/{Config.NUM_EPOCHS} ({epoch_time:.1f}s) | "
              f"LR: {current_lr:.6f}")
        print(f"  Train Loss: {train_loss:.4f} | Train Acc: {train_acc:.4f}")
        print(f"  Val Loss:   {val_loss:.4f} | Val Acc:   {val_acc:.4f}")
        
        # Check best model
        if val_acc > best_val_acc:
            best_val_acc = val_acc
            best_model_wts = copy.deepcopy(model.state_dict())
            patience_counter = 0
            
            # Save best model
            save_path = Config.MODELS_DIR / "best_model.pth"
            torch.save({
                'epoch': epoch,
                'model_state_dict': model.state_dict(),
                'optimizer_state_dict': optimizer.state_dict(),
                'val_acc': val_acc.item(),
                'val_loss': val_loss,
                'class_names': class_names,
                'num_classes': num_classes,
                'config': {
                    'image_size': Config.IMAGE_SIZE,
                    'model_name': Config.MODEL_NAME,
                }
            }, save_path)
            print(f"  ⭐ Best model saved! (Val Acc: {val_acc:.4f})")
        else:
            patience_counter += 1
            print(f"  ⏳ No improvement ({patience_counter}/{Config.EARLY_STOPPING_PATIENCE})")
        
        # Save checkpoint every epoch for resume capability
        checkpoint_path = Config.MODELS_DIR / "training_checkpoint.pth"
        torch.save({
            'epoch': epoch,
            'model_state_dict': model.state_dict(),
            'optimizer_state_dict': optimizer.state_dict(),
            'scheduler_state_dict': scheduler.state_dict(),
            'best_val_acc': best_val_acc,
            'patience_counter': patience_counter,
            'history': history,
            'class_names': class_names,
            'num_classes': num_classes,
        }, checkpoint_path)
        
        # Early stopping
        if patience_counter >= Config.EARLY_STOPPING_PATIENCE:
            print(f"\n⛔ Early stopping at epoch {epoch+1}!")
            break
    
    # Remove checkpoint file after successful completion
    checkpoint_path = Config.MODELS_DIR / "training_checkpoint.pth"
    if checkpoint_path.exists():
        checkpoint_path.unlink()
        print("   Checkpoint file removed (training complete)")
    
    total_time = time.time() - start_time
    print(f"\n✅ Training selesai dalam {total_time/60:.1f} menit")
    print(f"⭐ Best Val Accuracy: {best_val_acc:.4f}")
    
    # Load best model weights
    model.load_state_dict(best_model_wts)
    
    return model, history


# ============================================================
# EVALUASI
# ============================================================
def evaluate_model(model, test_loader, class_names):
    """Evaluasi model pada test set."""
    print("\n" + "=" * 60)
    print("  📊 EVALUASI MODEL")
    print("=" * 60)
    
    model.eval()
    all_preds = []
    all_labels = []
    all_probs = []
    
    with torch.no_grad():
        for inputs, labels in tqdm(test_loader, desc="Testing", ncols=80):
            inputs = inputs.to(Config.DEVICE)
            labels = labels.to(Config.DEVICE)
            
            outputs = model(inputs)
            probs = torch.softmax(outputs, dim=1)
            _, preds = torch.max(outputs, 1)
            
            all_preds.extend(preds.cpu().numpy())
            all_labels.extend(labels.cpu().numpy())
            all_probs.extend(probs.cpu().numpy())
    
    all_preds = np.array(all_preds)
    all_labels = np.array(all_labels)
    
    # Overall accuracy
    accuracy = np.mean(all_preds == all_labels)
    print(f"\n🎯 Test Accuracy: {accuracy:.4f} ({accuracy*100:.2f}%)")
    
    # Classification Report
    print(f"\n📋 Classification Report:")
    report = classification_report(all_labels, all_preds, target_names=class_names)
    print(report)
    
    # Save report
    report_path = Config.LOGS_DIR / "classification_report.txt"
    with open(report_path, "w") as f:
        f.write(f"Test Accuracy: {accuracy:.4f}\n\n")
        f.write(report)
    print(f"   Saved to: {report_path}")
    
    # Confusion Matrix
    cm = confusion_matrix(all_labels, all_preds)
    plot_confusion_matrix(cm, class_names)
    
    return accuracy, report


def plot_confusion_matrix(cm, class_names):
    """Plot dan simpan confusion matrix."""
    fig, ax = plt.subplots(figsize=(max(12, len(class_names)*0.5), max(10, len(class_names)*0.4)))
    
    sns.heatmap(cm, annot=True, fmt='d', cmap='Blues',
                xticklabels=class_names, yticklabels=class_names,
                ax=ax)
    
    ax.set_xlabel('Predicted', fontsize=12)
    ax.set_ylabel('Actual', fontsize=12)
    ax.set_title('Confusion Matrix - BISINDO Classification', fontsize=14)
    plt.xticks(rotation=45, ha='right', fontsize=8)
    plt.yticks(rotation=0, fontsize=8)
    plt.tight_layout()
    
    save_path = Config.LOGS_DIR / "confusion_matrix.png"
    plt.savefig(save_path, dpi=150, bbox_inches='tight')
    plt.close()
    print(f"   Confusion matrix saved to: {save_path}")


def plot_training_history(history):
    """Plot training history (loss & accuracy)."""
    fig, axes = plt.subplots(1, 3, figsize=(18, 5))
    
    epochs = range(1, len(history['train_loss']) + 1)
    
    # Loss
    axes[0].plot(epochs, history['train_loss'], 'b-', label='Train Loss')
    axes[0].plot(epochs, history['val_loss'], 'r-', label='Val Loss')
    axes[0].set_title('Loss per Epoch')
    axes[0].set_xlabel('Epoch')
    axes[0].set_ylabel('Loss')
    axes[0].legend()
    axes[0].grid(True, alpha=0.3)
    
    # Accuracy
    axes[1].plot(epochs, history['train_acc'], 'b-', label='Train Acc')
    axes[1].plot(epochs, history['val_acc'], 'r-', label='Val Acc')
    axes[1].set_title('Accuracy per Epoch')
    axes[1].set_xlabel('Epoch')
    axes[1].set_ylabel('Accuracy')
    axes[1].legend()
    axes[1].grid(True, alpha=0.3)
    
    # Learning Rate
    axes[2].plot(epochs, history['lr'], 'g-')
    axes[2].set_title('Learning Rate per Epoch')
    axes[2].set_xlabel('Epoch')
    axes[2].set_ylabel('Learning Rate')
    axes[2].grid(True, alpha=0.3)
    
    plt.suptitle('Training History - HandTalk BISINDO', fontsize=14)
    plt.tight_layout()
    
    save_path = Config.LOGS_DIR / "training_history.png"
    plt.savefig(save_path, dpi=150, bbox_inches='tight')
    plt.close()
    print(f"   Training history saved to: {save_path}")


# ============================================================
# MAIN
# ============================================================
def main():
    print("=" * 60)
    print("  HANDTALK BISINDO - Model Training Pipeline")
    print("=" * 60)
    print(f"  Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"  Device: {Config.DEVICE}")
    print(f"  PyTorch: {torch.__version__}")
    
    # Cek CUDA
    if torch.cuda.is_available():
        print(f"  GPU: {torch.cuda.get_device_name(0)}")
        print(f"  CUDA: {torch.version.cuda}")
    else:
        print("  GPU: Tidak tersedia (menggunakan CPU)")
        print("  ⚠️  Training akan lebih lambat tanpa GPU")
    
    # Buat direktori
    Config.MODELS_DIR.mkdir(parents=True, exist_ok=True)
    Config.LOGS_DIR.mkdir(parents=True, exist_ok=True)
    
    # Load dataset info
    info_path = Config.BASE_DIR / "dataset_info.json"
    if not info_path.exists():
        print("\n❌ dataset_info.json tidak ditemukan!")
        print("   Jalankan 01_download_dataset.py terlebih dahulu.")
        sys.exit(1)
    
    with open(info_path) as f:
        dataset_info = json.load(f)
    
    dataset_path = dataset_info["dataset_path"]
    print(f"\n📁 Dataset: {dataset_path}")
    
    # Step 1: Load dataset
    image_paths, labels, class_names, class_to_idx = load_dataset(dataset_path)
    
    if len(image_paths) == 0:
        print("❌ Tidak ada gambar ditemukan!")
        sys.exit(1)
    
    num_classes = len(class_names)
    
    # Save class mapping
    mapping_path = Config.MODELS_DIR / "class_mapping.json"
    with open(mapping_path, "w") as f:
        json.dump({
            "class_to_idx": class_to_idx,
            "idx_to_class": {v: k for k, v in class_to_idx.items()},
            "class_names": class_names
        }, f, indent=2)
    print(f"\n💾 Class mapping saved to: {mapping_path}")
    
    # Step 2: Split dataset
    train_data, val_data, test_data = split_dataset(image_paths, labels, class_names)
    
    # Step 3: Create data loaders
    train_transform, val_transform = get_transforms()
    
    train_dataset = BISINDODataset(train_data[0], train_data[1], train_transform)
    val_dataset = BISINDODataset(val_data[0], val_data[1], val_transform)
    test_dataset = BISINDODataset(test_data[0], test_data[1], val_transform)
    
    train_loader = DataLoader(train_dataset, batch_size=Config.BATCH_SIZE,
                             shuffle=True, num_workers=Config.NUM_WORKERS,
                             pin_memory=True)
    val_loader = DataLoader(val_dataset, batch_size=Config.BATCH_SIZE,
                           shuffle=False, num_workers=Config.NUM_WORKERS,
                           pin_memory=True)
    test_loader = DataLoader(test_dataset, batch_size=Config.BATCH_SIZE,
                            shuffle=False, num_workers=Config.NUM_WORKERS,
                            pin_memory=True)
    
    print(f"\n📦 DataLoaders:")
    print(f"   Train: {len(train_loader)} batches")
    print(f"   Val:   {len(val_loader)} batches")
    print(f"   Test:  {len(test_loader)} batches")
    
    # Step 4: Create model
    model = create_model(num_classes)
    
    # Step 5: Train
    model, history = train_model(model, train_loader, val_loader, num_classes, class_names)
    
    # Step 6: Plot training history
    plot_training_history(history)
    
    # Step 7: Evaluate on test set
    accuracy, report = evaluate_model(model, test_loader, class_names)
    
    # Step 8: Save final model info
    final_info = {
        "model_name": Config.MODEL_NAME,
        "num_classes": num_classes,
        "class_names": class_names,
        "image_size": Config.IMAGE_SIZE,
        "test_accuracy": float(accuracy),
        "training_epochs": len(history['train_loss']),
        "best_val_acc": max(history['val_acc']),
        "timestamp": datetime.now().isoformat(),
        "normalization": {
            "mean": [0.485, 0.456, 0.406],
            "std": [0.229, 0.224, 0.225]
        }
    }
    
    info_save_path = Config.MODELS_DIR / "model_info.json"
    with open(info_save_path, "w") as f:
        json.dump(final_info, f, indent=2)
    
    print("\n" + "=" * 60)
    print("  ✅ TRAINING PIPELINE SELESAI!")
    print("=" * 60)
    print(f"\n📊 Hasil:")
    print(f"   Test Accuracy: {accuracy*100:.2f}%")
    print(f"   Best Val Accuracy: {max(history['val_acc'])*100:.2f}%")
    print(f"\n📁 File yang dihasilkan:")
    print(f"   Model: {Config.MODELS_DIR / 'best_model.pth'}")
    print(f"   Class mapping: {mapping_path}")
    print(f"   Model info: {info_save_path}")
    print(f"   Training history: {Config.LOGS_DIR / 'training_history.png'}")
    print(f"   Confusion matrix: {Config.LOGS_DIR / 'confusion_matrix.png'}")
    print(f"   Classification report: {Config.LOGS_DIR / 'classification_report.txt'}")
    print(f"\n➡️  Langkah selanjutnya: jalankan 03_export_tflite.py")


if __name__ == "__main__":
    main()
