from model.embedding_pipeline import create_data_loader, extract_features
from eval.knn import FAISSKNN
from pathlib import Path
import glob


def main():
    ROOT = Path(__file__).resolve().parents[1]  # adjust if needed
    # train_dl, test_dl = create_data_loader(batch_size=64)
    # extract_features(train_dl, test_dl)

    DIM = 768
    K = 5

    knn = FAISSKNN(dim=DIM, k=K)

    train_feats = sorted(ROOT.glob("features/train_batch_*.pt"))
    train_labels = sorted(ROOT.glob("features/train_labels_*.pt"))

    knn.fit(train_feats, train_labels)

    test_feats = sorted(ROOT.glob("features/test_batch_*.pt"))
    test_labels = sorted(ROOT.glob("features/test_labels_*.pt"))

    acc = knn.evaluate(test_feats, test_labels)

    print(f"KNN accuracy (k={K}): {acc:.4f}")

if __name__ == "__main__":
    main()