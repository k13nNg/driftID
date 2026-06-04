import torch
import torch.nn as nn

DROPOUT_RATE = 0.2

class LinearClassifier(nn.Module):
    def __init__(self, input_dim, num_classes):
        super().__init__()
        self.classifier = nn.Sequential(
            nn.Dropout(DROPOUT_RATE),
            nn.Linear(input_dim, num_classes)
        )

    def forward(self, x):
        return self.classifier(x)