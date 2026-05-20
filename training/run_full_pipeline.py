"""
=============================================================
HandTalk BISINDO - Full Training Pipeline (Background Runner)
=============================================================
Runs:
1. Create checkpoint from existing best_model.pth (for resume)
2. Train model (02_train_model.py) - resumes from checkpoint
3. Export to ONNX/TFLite (03_export_tflite.py)
4. Log completion status

Output is logged to: training/logs/pipeline_output.log
=============================================================
"""
import subprocess
import sys
import os
import time
from pathlib import Path
from datetime import datetime

TRAINING_DIR = Path(__file__).parent
LOG_DIR = TRAINING_DIR / "logs"
LOG_DIR.mkdir(parents=True, exist_ok=True)
LOG_FILE = LOG_DIR / "pipeline_output.log"
STATUS_FILE = LOG_DIR / "pipeline_status.txt"

def log(msg):
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    line = f"[{timestamp}] {msg}"
    print(line, flush=True)
    with open(LOG_FILE, "a", encoding="utf-8") as f:
        f.write(line + "\n")

def update_status(status):
    with open(STATUS_FILE, "w", encoding="utf-8") as f:
        f.write(f"{status}\n")
        f.write(f"Updated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")

def run_script(script_name, description):
    """Run a Python script and stream output to log."""
    script_path = TRAINING_DIR / script_name
    log(f"--- Starting: {description} ({script_name}) ---")
    
    process = subprocess.Popen(
        [sys.executable, str(script_path)],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        cwd=str(TRAINING_DIR),
        encoding='utf-8',
        errors='replace',
        bufsize=1
    )
    
    with open(LOG_FILE, "a", encoding="utf-8") as f:
        for line in process.stdout:
            f.write(line)
            f.flush()
    
    process.wait()
    
    if process.returncode != 0:
        log(f"ERROR: {script_name} exited with code {process.returncode}")
        return False
    
    log(f"--- Completed: {description} ---")
    return True

def main():
    start_time = time.time()
    
    # Clear log file
    with open(LOG_FILE, "w", encoding="utf-8") as f:
        f.write(f"=== HandTalk BISINDO Training Pipeline ===\n")
        f.write(f"Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"{'='*60}\n\n")
    
    update_status("RUNNING: Creating checkpoint for resume")
    
    # Step 1: Create checkpoint from existing best_model.pth
    checkpoint_path = TRAINING_DIR / "models" / "training_checkpoint.pth"
    if not checkpoint_path.exists():
        best_model_path = TRAINING_DIR / "models" / "best_model.pth"
        if best_model_path.exists():
            log("Creating checkpoint from existing best_model.pth for resume...")
            success = run_script("create_checkpoint.py", "Create Resume Checkpoint")
            if not success:
                log("WARNING: Could not create checkpoint, training will start from scratch")
        else:
            log("No existing model found, training will start from scratch")
    else:
        log("Checkpoint already exists, will resume from it")
    
    # Step 2: Training
    update_status("RUNNING: Training model (02_train_model.py)")
    log("\n" + "="*60)
    log("STEP 2: TRAINING MODEL")
    log("="*60)
    
    success = run_script("02_train_model.py", "Model Training (30 epochs)")
    if not success:
        update_status("FAILED: Training failed")
        log("PIPELINE FAILED at training step!")
        return
    
    # Step 3: Export
    update_status("RUNNING: Exporting model (03_export_tflite.py)")
    log("\n" + "="*60)
    log("STEP 3: EXPORT MODEL TO ONNX/TFLITE")
    log("="*60)
    
    success = run_script("03_export_tflite.py", "Export to ONNX/TFLite")
    if not success:
        update_status("FAILED: Export failed")
        log("PIPELINE FAILED at export step!")
        return
    
    # Done
    elapsed = time.time() - start_time
    elapsed_str = f"{elapsed/3600:.1f} hours" if elapsed > 3600 else f"{elapsed/60:.1f} minutes"
    
    update_status(f"COMPLETED: Pipeline finished in {elapsed_str}")
    log(f"\n{'='*60}")
    log(f"PIPELINE COMPLETED SUCCESSFULLY in {elapsed_str}")
    log(f"{'='*60}")
    log(f"Check results:")
    log(f"  - Model: training/models/best_model.pth")
    log(f"  - Report: training/logs/classification_report.txt")
    log(f"  - Flutter assets: handtalk/assets/models/")

if __name__ == "__main__":
    main()
