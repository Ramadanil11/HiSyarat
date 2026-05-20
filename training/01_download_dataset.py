"""
=============================================================
HandTalk BISINDO - Step 1: Download Dataset dari Kaggle
=============================================================
Script ini mendownload dataset BISINDO dari Kaggle menggunakan
kagglehub dan mengeksplorasi strukturnya.

Dataset: sifaqeinstein/bisindo
=============================================================
"""

import kagglehub
import os
import json
from pathlib import Path
from collections import Counter

def download_dataset():
    """Download dataset BISINDO dari Kaggle."""
    print("=" * 60)
    print("  HANDTALK BISINDO - Download Dataset")
    print("=" * 60)
    
    print("\n[1/3] Downloading dataset dari Kaggle...")
    print("       Dataset: sifaqeinstein/bisindo")
    
    # Download dataset
    path = kagglehub.dataset_download("sifaqeinstein/bisindo")
    print(f"\n✅ Dataset berhasil didownload!")
    print(f"📁 Path: {path}")
    
    return path


def explore_dataset(dataset_path):
    """Eksplorasi struktur dataset."""
    print("\n" + "=" * 60)
    print("  [2/3] Eksplorasi Dataset")
    print("=" * 60)
    
    dataset_path = Path(dataset_path)
    
    # List semua folder dan file
    print(f"\n📂 Struktur folder di: {dataset_path}")
    
    all_items = list(dataset_path.rglob("*"))
    dirs = [x for x in all_items if x.is_dir()]
    files = [x for x in all_items if x.is_file()]
    
    print(f"   Total folder: {len(dirs)}")
    print(f"   Total file: {len(files)}")
    
    # Cek ekstensi file
    extensions = Counter(f.suffix.lower() for f in files)
    print(f"\n📊 Distribusi ekstensi file:")
    for ext, count in extensions.most_common():
        print(f"   {ext or '(no ext)'}: {count} files")
    
    # Cek apakah ada subfolder (kelas)
    image_extensions = {'.jpg', '.jpeg', '.png', '.bmp', '.gif', '.webp'}
    image_files = [f for f in files if f.suffix.lower() in image_extensions]
    
    print(f"\n🖼️  Total gambar: {len(image_files)}")
    
    # Analisis per kelas (berdasarkan parent folder)
    if image_files:
        class_counts = Counter()
        for img in image_files:
            # Ambil nama folder parent sebagai label kelas
            class_name = img.parent.name
            class_counts[class_name] += 1
        
        print(f"\n📋 Jumlah kelas: {len(class_counts)}")
        print(f"\n{'Kelas':<30} {'Jumlah Gambar':>15}")
        print("-" * 47)
        
        total = 0
        class_info = {}
        for cls, count in sorted(class_counts.items()):
            print(f"   {cls:<27} {count:>12}")
            class_info[cls] = count
            total += count
        
        print("-" * 47)
        print(f"   {'TOTAL':<27} {total:>12}")
        
        # Statistik
        counts = list(class_counts.values())
        print(f"\n📈 Statistik:")
        print(f"   Min gambar per kelas: {min(counts)}")
        print(f"   Max gambar per kelas: {max(counts)}")
        print(f"   Rata-rata: {sum(counts)/len(counts):.1f}")
        
        # Cek resolusi sample gambar
        try:
            from PIL import Image
            sample_img = Image.open(str(image_files[0]))
            print(f"\n🔍 Sample gambar: {image_files[0].name}")
            print(f"   Resolusi: {sample_img.size}")
            print(f"   Mode: {sample_img.mode}")
        except Exception as e:
            print(f"\n⚠️  Gagal baca sample gambar: {e}")
        
        return class_info, str(dataset_path)
    
    # Jika tidak ada gambar, cek file lain
    print("\n⚠️  Tidak ditemukan file gambar langsung.")
    print("   Mungkin dataset dalam format lain (CSV, ZIP, dll)")
    
    # List semua folder level 1
    print("\n📂 Folder level 1:")
    for item in sorted(dataset_path.iterdir()):
        if item.is_dir():
            sub_count = len(list(item.rglob("*")))
            print(f"   📁 {item.name}/ ({sub_count} items)")
        else:
            print(f"   📄 {item.name} ({item.stat().st_size / 1024:.1f} KB)")
    
    return {}, str(dataset_path)


def save_dataset_info(class_info, dataset_path):
    """Simpan informasi dataset ke file JSON."""
    print("\n" + "=" * 60)
    print("  [3/3] Menyimpan Informasi Dataset")
    print("=" * 60)
    
    info = {
        "dataset_source": "kaggle:sifaqeinstein/bisindo",
        "dataset_path": dataset_path,
        "num_classes": len(class_info),
        "total_images": sum(class_info.values()) if class_info else 0,
        "classes": class_info
    }
    
    output_path = Path(__file__).parent / "dataset_info.json"
    with open(output_path, "w") as f:
        json.dump(info, f, indent=2)
    
    print(f"✅ Info dataset disimpan ke: {output_path}")
    
    return info


if __name__ == "__main__":
    # Step 1: Download
    dataset_path = download_dataset()
    
    # Step 2: Explore
    class_info, path_str = explore_dataset(dataset_path)
    
    # Step 3: Save info
    info = save_dataset_info(class_info, path_str)
    
    print("\n" + "=" * 60)
    print("  ✅ SELESAI!")
    print("=" * 60)
    print(f"\n📁 Dataset path: {path_str}")
    print(f"📊 Jumlah kelas: {info['num_classes']}")
    print(f"🖼️  Total gambar: {info['total_images']}")
    print(f"\n➡️  Langkah selanjutnya: jalankan 02_train_model.py")
