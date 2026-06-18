import torch
import torch.nn as nn

DROPOUT_RATE = 0.2
INTER_LAYER = 256

class LinearClassifier(nn.Module):
    def __init__(self, input_dim, num_classes):
        super().__init__()
        print("input_dim:", input_dim)
        print("num_classes:", num_classes)
        self.classifier = nn.Sequential(
            nn.Dropout(DROPOUT_RATE),
            nn.Linear(input_dim, INTER_LAYER),
            nn.ReLU(),
            nn.Linear(INTER_LAYER, INTER_LAYER),
            nn.ReLU(),
            nn.Linear(INTER_LAYER, INTER_LAYER),
            nn.ReLU(),
            nn.Linear(INTER_LAYER, INTER_LAYER),
            nn.ReLU(),
            nn.Linear(INTER_LAYER, num_classes),
        )

    def forward(self, x):
        return self.classifier(x)