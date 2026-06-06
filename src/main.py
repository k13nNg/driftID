import faiss
import json
import numpy as np
import torch
import torch.nn as nn
from dataset_processing.car_ds_class import CarImageDataset
from model.linear_classifier import LinearClassifier
from dataset_processing.create_dataloaders import create_features_dl
from train.trainer import train_model

# load the saved index of embeddings
index = faiss.read_index("./data/train/train_index")
labels = np.load("./data/train/train_labels.npy")

# reconstruct all vector emeddings
train_features = index.reconstruct_n(0, index.ntotal)

# convert vector embeddings from numpy to torch tensors for embeddings
train_features = torch.from_numpy(train_features).float()
train_labels = torch.from_numpy(labels).long()

# load the training dataset to get the classes
# number of classes are the same across train_dataset.json, test_dataset.json and dataset_meta.json
# this implies there is no classes missing in train_dataset.json
# thus, it's safe to grab NUM_CLASSES from train_dataset
ds = CarImageDataset("./data/json/train_dataset.json")

# save classes for inference later
with open("./data/artifacts/classes.json", "w") as f:
    json.dump(ds.classes, f, indent = 4 )

# define params for training
NUM_CLASSES = len(ds.classes)
DIM = index.d
EPOCH_NUM = 100

train_features_dl = create_features_dl(train_features, train_labels)

classifier = LinearClassifier(DIM, NUM_CLASSES)
loss_func = nn.CrossEntropyLoss()
optimizer = torch.optim.Adam(classifier.parameters(), lr=1e-3)

trained_classifier = train_model(classifier, loss_func, optimizer, train_features_dl)

torch.save( 
    {
        "model_state_dict": classifier.state_dict(),
        "dim": DIM,
        "num_classes": NUM_CLASSES,
    },
    "linear_classifier.pt"
)



