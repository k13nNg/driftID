import faiss
import torch
import torch.nn.functional as F
from collections import Counter
import numpy as np

class FAISSKNN:
    def __init__(self, dim: int, k: int = 5):
        self.k = k
        self.index = faiss.IndexFlatIP(dim)  # cosine similarity (after normalization)
        self.train_labels = None

    def fit(self, feature_files, label_files):
        """
        Build FAISS index from batched feature + label files.
        """
        all_labels = []

        for feat_file, label_file in zip(feature_files, label_files):
            feats = torch.load(feat_file)
            labels = torch.load(label_file)

            # normalize for cosine similarity
            feats = F.normalize(feats, dim=1)

            # add to FAISS
            self.index.add(feats.cpu().numpy().astype(np.float32))

            all_labels.append(labels)

        self.train_labels = torch.cat(all_labels, dim=0).long()

        assert self.train_labels.shape[0] == self.index.ntotal, \
            "Mismatch between FAISS vectors and labels!"

    def predict(self, x: torch.Tensor):
        """
        Predict labels for a batch of test embeddings.
        """
        # 1. normalize and convert 
        x = F.normalize(x, dim=1)
        x_np = x.detach().cpu().numpy().astype(np.float32)

        # 2. FAISS search, only care about indices, not distances
        _, indices = self.index.search(x_np, self.k)

        # 3. convert to torch
        indices = torch.tensor(indices, dtype=torch.long)

        preds = []

        # 4. pure torch indexing + python voting
        for neighbors in indices:
            neighbor_labels = self.train_labels[neighbors].tolist()

            preds.append(
                Counter(neighbor_labels).most_common(1)[0][0]
            )

        return torch.tensor(preds, device=x.device, dtype=torch.long)

    def evaluate(self, test_feature_files, test_label_files):
        '''
        Evaluate the accuracy of KNN
        '''
        correct = 0
        total = 0

        for feat_file, label_file in zip(test_feature_files, test_label_files):
            feats = torch.load(feat_file)
            labels = torch.load(label_file)

            preds = self.predict(feats)

            correct += (preds == labels).sum().item()
            total += labels.size(0)

        acc = correct / total
        return acc