"""
Create a training checkpoint from existing best_model.pth
so that training can resume from epoch 2.
"""
import torch
import torch.optim as optim
from torch.optim.lr_scheduler import StepLR
from torchvision import models
import torch.nn as nn
from pathlib import Path

MODELS_DIR = Path(__file__).parent / "models"
best_model_path = MODELS_DIR / "best_model.pth"
checkpoint_path = MODELS_DIR / "training_checkpoint.pth"

print(f"Loading best_model.pth...")
ckpt = torch.load(best_model_path, map_location='cpu', weights_only=False)

print(f"  Epoch: {ckpt['epoch']}")
print(f"  Val Acc: {ckpt['val_acc']:.4f}")
print(f"  Num Classes: {ckpt['num_classes']}")

# Recreate model to get optimizer/scheduler states
num_classes = ckpt['num_classes']
model = models.mobilenet_v2(weights=None)
num_features = model.classifier[1].in_features
model.classifier = nn.Sequential(
    nn.Dropout(p=0.3),
    nn.Linear(num_features, 256),
    nn.ReLU(),
    nn.Dropout(p=0.2),
    nn.Linear(256, num_classes)
)
model.load_state_dict(ckpt['model_state_dict'])

# Create optimizer and step it once (for epoch 0 -> 1 transition)
optimizer = optim.Adam(
    filter(lambda p: p.requires_grad, model.parameters()),
    lr=0.001,
    weight_decay=1e-4
)
if 'optimizer_state_dict' in ckpt:
    try:
        optimizer.load_state_dict(ckpt['optimizer_state_dict'])
        print("  Optimizer state loaded successfully")
    except (ValueError, RuntimeError) as e:
        print(f"  WARNING: Could not load optimizer state ({e}), using fresh optimizer")
        print("  This is normal if model architecture changed")

scheduler = StepLR(optimizer, step_size=7, gamma=0.1)
# Step scheduler once for epoch 0
scheduler.step()

# Create full checkpoint
training_checkpoint = {
    'epoch': ckpt['epoch'],  # epoch 0 completed
    'model_state_dict': ckpt['model_state_dict'],
    'optimizer_state_dict': optimizer.state_dict(),
    'scheduler_state_dict': scheduler.state_dict(),
    'best_val_acc': ckpt['val_acc'],
    'patience_counter': 0,
    'history': {
        'train_loss': [2.0470],
        'train_acc': [0.4095],
        'val_loss': [1.0386],
        'val_acc': [0.7077],
        'lr': [0.001]
    },
    'class_names': ckpt['class_names'],
    'num_classes': ckpt['num_classes'],
}

torch.save(training_checkpoint, checkpoint_path)
print(f"\nCheckpoint saved to: {checkpoint_path}")
print(f"Training will resume from epoch 2/30")
