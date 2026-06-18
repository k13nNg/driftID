"""
Evaluate the trained LinearClassifier on the test dataset.

By default this script uses the pre-extracted test features saved during the
feature-extraction stage (data/test/test_feats.pt / test_labels.pt), which
avoids re-running the DINOv3 backbone and is much faster.

Pass --full-eval to extract features on-the-fly directly from the raw images
using data/json/test_dataset.json instead.

Usage
-----
# Fast path (pre-extracted features)
python src/eval/eval_linear_classifier.py

# Full path (raw images → DINOv3 → LinearClassifier)
python src/eval/eval_linear_classifier.py --full-eval
"""

import argparse
import json
import sys
from pathlib import Path

import numpy as np
import torch
import torch.nn.functional as F
import timm
from tqdm import tqdm
from torch.utils.data import DataLoader

# ── project root on the path so relative imports work ──────────────────────
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "src"))

from model.linear_classifier import LinearClassifier
from dataset_processing.car_ds_class import CarImageDataset

# ── constants ───────────────────────────────────────────────────────────────
MODEL_NAME        = "vit_base_patch16_dinov3"
INPUT_SIZE        = 384
BATCH_SIZE        = 32
ARTIFACTS_DIR     = ROOT / "data" / "artifacts"
MODEL_PARAMS_PATH = ARTIFACTS_DIR / "deep_nn_classifier.pt"
CLASSES_PATH      = ARTIFACTS_DIR / "classes.json"
TEST_FEATS_PATH   = ROOT / "data" / "test" / "test_feats.pt"
TEST_LABELS_PATH  = ROOT / "data" / "test" / "test_labels.pt"
TEST_JSON_PATH    = ROOT / "data" / "json" / "test_dataset.json"
DEVICE            = torch.device("cuda" if torch.cuda.is_available() else "cpu")


# ── helpers ─────────────────────────────────────────────────────────────────

def load_classifier() -> LinearClassifier:
    """Load the trained LinearClassifier from the saved checkpoint."""
    checkpoint = torch.load(MODEL_PARAMS_PATH, map_location=DEVICE)
    classifier = LinearClassifier(checkpoint["dim"], checkpoint["num_classes"])
    classifier.load_state_dict(checkpoint["model_state_dict"])
    classifier.to(DEVICE)
    classifier.eval()
    return classifier


def load_feature_extractor():
    """Load DINOv3 backbone (feature extractor only, num_classes=0)."""
    model = timm.create_model(MODEL_NAME, pretrained=True, num_classes=0)
    model.to(DEVICE)
    model.eval()
    return model


def build_test_dataloader() -> DataLoader:
    """Build a DataLoader over the raw test images."""
    data_config = timm.data.resolve_model_data_config(MODEL_NAME)
    data_config["input_size"] = (3, INPUT_SIZE, INPUT_SIZE)
    transform = timm.data.create_transform(**data_config, is_training=False)

    dataset = CarImageDataset(TEST_JSON_PATH, transform=transform)
    return DataLoader(
        dataset,
        batch_size=BATCH_SIZE,
        shuffle=False,
        num_workers=4,
        pin_memory=True,
        prefetch_factor=4,
        persistent_workers=True,
    )


def extract_and_classify_full(classifier, feature_extractor, dataloader):
    """
    Full evaluation path: raw images → DINOv3 embeddings → LinearClassifier.
    Returns (all_preds, all_labels) as numpy arrays.
    """
    all_preds  = []
    all_labels = []

    with torch.no_grad():
        for images, labels in tqdm(dataloader, desc="Evaluating (full)"):
            images = images.to(DEVICE)

            # extract L2-normalised embeddings
            embeddings = feature_extractor(images)
            embeddings = F.normalize(embeddings, p=2, dim=1)

            logits = classifier(embeddings)
            preds  = logits.argmax(dim=1)

            all_preds.append(preds.cpu().numpy())
            all_labels.append(labels.numpy())

    return np.concatenate(all_preds), np.concatenate(all_labels)


def classify_from_saved_features(classifier):
    """
    Fast evaluation path: load pre-extracted features and run LinearClassifier.
    Returns (all_preds, all_labels) as numpy arrays.
    """
    test_feats  = torch.load(TEST_FEATS_PATH,  map_location=DEVICE)
    test_labels = torch.load(TEST_LABELS_PATH, map_location="cpu")

    all_preds  = []
    all_labels = []

    with torch.no_grad():
        for start in tqdm(range(0, len(test_feats), BATCH_SIZE), desc="Evaluating (fast)"):
            end    = min(start + BATCH_SIZE, len(test_feats))
            batch  = test_feats[start:end].to(DEVICE)
            logits = classifier(batch)
            preds  = logits.argmax(dim=1)

            all_preds.append(preds.cpu().numpy())
            all_labels.append(test_labels[start:end].numpy())

    return np.concatenate(all_preds), np.concatenate(all_labels)


def compute_top_k_accuracy(logits_or_preds, labels, k=5):
    """
    Compute top-k accuracy from raw logits tensor (N, C) and label tensor (N,).
    Only used in the fast path where we can keep logits in memory.
    """
    top_k_preds = torch.topk(logits_or_preds, k=k, dim=1).indices  # (N, k)
    labels_exp  = labels.unsqueeze(1).expand_as(top_k_preds)        # (N, k)
    correct     = top_k_preds.eq(labels_exp).any(dim=1).sum().item()
    return correct / len(labels)


def compute_metrics(all_preds, all_labels, classes):
    """
    Compute and print:
      - Overall top-1 accuracy
      - Per-class accuracy
      - Worst-5 / Best-5 classes
    """
    num_classes = len(classes)
    correct_per_class = np.zeros(num_classes, dtype=np.int64)
    total_per_class   = np.zeros(num_classes, dtype=np.int64)

    for pred, label in zip(all_preds, all_labels):
        total_per_class[label]   += 1
        correct_per_class[label] += int(pred == label)

    overall_acc = correct_per_class.sum() / total_per_class.sum()

    # per-class accuracy (skip classes with 0 test samples)
    per_class_acc = np.where(
        total_per_class > 0,
        correct_per_class / total_per_class,
        np.nan,
    )

    # sort for best / worst
    valid_mask    = ~np.isnan(per_class_acc)
    valid_indices = np.where(valid_mask)[0]
    sorted_idx    = valid_indices[np.argsort(per_class_acc[valid_indices])]

    print("\n" + "=" * 60)
    print(f"  Overall Top-1 Accuracy : {overall_acc * 100:.2f}%")
    print(f"  Total samples          : {int(total_per_class.sum())}")
    print("=" * 60)

    print("\n  Worst 5 classes:")
    for i in sorted_idx[:5]:
        print(f"    {classes[i]:<55}  {per_class_acc[i] * 100:.1f}%  ({correct_per_class[i]}/{total_per_class[i]})")

    print("\n  Best 5 classes:")
    for i in sorted_idx[-5:][::-1]:
        print(f"    {classes[i]:<55}  {per_class_acc[i] * 100:.1f}%  ({correct_per_class[i]}/{total_per_class[i]})")

    print("=" * 60 + "\n")

    return overall_acc, per_class_acc


# ── main ────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Evaluate the LinearClassifier on the test set.")
    parser.add_argument(
        "--full-eval",
        action="store_true",
        help="Extract features from raw images instead of using saved test_feats.pt",
    )
    parser.add_argument(
        "--batch-size",
        type=int,
        default=BATCH_SIZE,
        help=f"Batch size (default: {BATCH_SIZE})",
    )
    args = parser.parse_args()

    # load classes
    with open(CLASSES_PATH) as f:
        classes = json.load(f)

    print(f"\nDevice     : {DEVICE}")
    print(f"Classes    : {len(classes)}")
    print(f"Checkpoint : {MODEL_PARAMS_PATH.relative_to(ROOT)}")

    classifier = load_classifier()

    if args.full_eval:
        print("\nMode: full evaluation (raw images → DINOv3 → classifier)\n")
        feature_extractor = load_feature_extractor()
        dataloader        = build_test_dataloader()
        all_preds, all_labels = extract_and_classify_full(classifier, feature_extractor, dataloader)
    else:
        print(f"\nMode: fast evaluation (pre-extracted features from {TEST_FEATS_PATH.relative_to(ROOT)})\n")
        if not TEST_FEATS_PATH.exists() or not TEST_LABELS_PATH.exists():
            print(
                "ERROR: Pre-extracted test features not found.\n"
                f"  Expected: {TEST_FEATS_PATH}\n"
                f"           {TEST_LABELS_PATH}\n"
                "Re-run with --full-eval to extract features from raw images."
            )
            sys.exit(1)
        all_preds, all_labels = classify_from_saved_features(classifier)

    compute_metrics(all_preds, all_labels, classes)


if __name__ == "__main__":
    main()
