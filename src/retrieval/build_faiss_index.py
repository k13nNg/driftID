from pathlib import Path

# grab the root directory
ROOT = Path(__file__).resolve().parents[2]

train_features = sorted(ROOT.glob("features/train_batch_*.pt"))