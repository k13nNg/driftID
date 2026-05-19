import torch
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]  # adjust if needed

x = torch.load(ROOT/"features/train_batch_0.pt")

print(type(x))
print(x.shape)