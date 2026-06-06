from .linear_classifier import LinearClassifier
from pathlib import Path

import torch
import timm

# defining constants
ROOT = Path(__file__).resolve().parents[2]
MODEL_NAME = "vit_base_patch16_dinov3"
MODEL_PARAMS_PATH = ROOT/"data"/"artifacts"/"linear_classifier.pt"
CLASSES_PATH =  ROOT/"data"/"artifacts"/"classes.json"
DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")

def create_feature_extractor(model_name, device):
    """
    Initialize and return an instance of DINOv3 model as the feature extractor

    Note: DINOv3 is used to generate vector embeddings from images
    """
    feature_extractor = timm.create_model(
        model_name,
        pretrained=True,
        num_classes = 0
    )

    feature_extractor.to(device)
    feature_extractor.eval()

    return feature_extractor

def create_classifier(device):
    """
    Initialize and return an instance of LinearClassifier (the linear NN head added on top of DINOv3)
    """
    checkpoint = torch.load(
        MODEL_PARAMS_PATH,
        map_location = device
    )

    classifier = LinearClassifier(
        checkpoint["dim"],
        checkpoint["num_classes"]
    )

    classifier.load_state_dict(checkpoint["model_state_dict"])

    classifier.to(device)

    # set the classifier in eval mode
    classifier.eval()

    return classifier
