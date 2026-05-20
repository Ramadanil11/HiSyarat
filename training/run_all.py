"""
=============================================================
HandTalk BISINDO - Master Pipeline Runner
=============================================================
Jalankan script ini untuk menjalankan seluruh pipeline:
1. Download dataset
2. Training model
3. Export ke TFLite
4. Integrasi ke Flutter

Usage:
  python run_all.py           # Jalankan semua step
  python run_all.py --skip-download  # Skip download (jika sudah ada)
  python run_all.py --step 2  # Mulai dari step tertentu
=============================================================
"""

import sys
import subprocess
import argparse
from pathlib import Path

BASE_DIR = Path(__file__).parent

STEPS = [
    ("01_download_dataset.py", "Download Dataset dari Kaggle"),
    ("02_train_model.py", "Training Model Deep Learning"),
    ("03_export_tflite.py", "Export Model ke TFLite"),
    ("04_integrate_flutter.py", "Integrasi ke Flutter"),
]


def run_step(script_name, description, step_num):
    """Jalankan satu step dari pipeline."""
    print("\n" + "=" * 60)
    print(f"  STEP {step_num}: {description}")
    print(f"  Script: {script_name}")
    print("=" * 60)
    
    script_path = BASE_DIR / script_name
    if not script_path.exists():
        print(f"❌ Script tidak ditemukan: {script_path}")
        return False
    
    try:
        result = subprocess.run(
            [sys.executable, str(script_path)],
            cwd=str(BASE_DIR),
            check=True
        )
        print(f"\n✅ Step {step_num} selesai!")
        return True
    except subprocess.CalledProcessError as e:
        print(f"\n❌ Step {step_num} gagal! Exit code: {e.returncode}")
        return False
    except KeyboardInterrupt:
        print(f"\n⚠️ Step {step_num} dibatalkan oleh user")
        return False


def main():
    parser = argparse.ArgumentParser(description="HandTalk BISINDO Training Pipeline")
    parser.add_argument("--skip-download", action="store_true",
                       help="Skip dataset download step")
    parser.add_argument("--step", type=int, default=1,
                       help="Start from step number (1-4)")
    args = parser.parse_args()
    
    print("=" * 60)
    print("  HANDTALK BISINDO - Full Training Pipeline")
    print("=" * 60)
    print(f"\n📋 Pipeline Steps:")
    for i, (script, desc) in enumerate(STEPS, 1):
        status = "⏭️ SKIP" if (i == 1 and args.skip_download) or i < args.step else "⏳ PENDING"
        print(f"   {i}. {desc} [{status}]")
    
    print(f"\n🚀 Starting from step {args.step}...")
    
    start_step = args.step
    
    for i, (script, desc) in enumerate(STEPS, 1):
        if i < start_step:
            continue
        if i == 1 and args.skip_download:
            print(f"\n⏭️ Skipping step 1: {desc}")
            continue
        
        success = run_step(script, desc, i)
        if not success:
            print(f"\n❌ Pipeline stopped at step {i}")
            print(f"   Fix the issue and re-run with: python run_all.py --step {i}")
            sys.exit(1)
    
    print("\n" + "=" * 60)
    print("  🎉 PIPELINE SELESAI!")
    print("=" * 60)
    print("\n📱 Langkah terakhir:")
    print("   cd C:\\pcs_project\\handtalk")
    print("   flutter pub get")
    print("   flutter run")


if __name__ == "__main__":
    main()
