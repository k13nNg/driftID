from collections import Counter
import torch
import faiss
import numpy as np
import torch.nn.functional as F
from scipy.stats import mode

class KNN:
    """
    Implementation of KNN class to evaluate the cold embeddings quality of DINOv3, using FAISS retrieval method
    """
    def __init__(self, k, index_file_path, labels_file_path):
        self.index = faiss.read_index(index_file_path)
        self.labels = np.load(labels_file_path)
        self.k = k

    def predict(self, x):
        """
        predict k car classes that are nearest to x
        """
        # normalize x before searching
        x = F.normalize(x, dim = 1)
        x = x.detach().cpu().numpy().astype('float32')

        _, indices = self.index.search(x, self.k)

        preds = []

        # vectorized majority voting
        # axis=1 finds the mode along the rows (the k neighbors for each query)
        def majority_vote(indices, labels):
            preds = []

            for neighbors in indices:
                neighbor_labels = labels[neighbors]
                preds.append(Counter(neighbor_labels.tolist()).most_common(1)[0][0])

            return np.array(preds)

        # extract the wining labels and flatten to a 1D list
        # preds = voting_results.mode.ravel()
        preds = majority_vote(indices, self.labels)

        return preds

    def eval(self, test_feats_file_path, test_labels_file_path, batch_size = 10000):
        """
        Evaluate the retrieval quality based on the test dataset
        """
        test_feats = torch.load(test_feats_file_path)
        test_labels = torch.load(test_labels_file_path)

        correct = 0
        total = len(test_feats)

        for start in range(0, total, batch_size):

            end = min(start + batch_size, total)

            batch_feats = test_feats[start:end]

            preds = self.predict(batch_feats)

            labels = test_labels[start:end].numpy()

            correct += np.sum(preds == labels)

        accuracy = correct / total

        return accuracy