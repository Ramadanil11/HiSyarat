import sys, io, torch
if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
checkpoint = torch.load('C:/pcs_project/training/models/best_model.pth', map_location='cpu', weights_only=False)
print(f"Epoch: {checkpoint['epoch']}")
print(f"Val Acc: {checkpoint['val_acc']:.4f}")
print(f"Val Loss: {checkpoint['val_loss']:.4f}")
print(f"Num Classes: {checkpoint['num_classes']}")
print(f"Classes: {checkpoint['class_names']}")
print(f"Config: {checkpoint['config']}")
