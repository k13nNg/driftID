import torch
from PIL import Image
import timm

from .linear_classifier import LinearClassifier
import json
from io import BytesIO
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

import requests
# from dataset_processing.dataset import CarImageDataset

MODEL_NAME = "vit_base_patch16_dinov3"
MODEL_PARAMS_PATH = ROOT/"data"/"artifacts"/"linear_classifier.pt"
CLASSES_PATH =  ROOT/"data"/"artifacts"/"classes.json"
DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")
INPUT_SIZE = 384

def create_transforms(model_name, input_size):
    # create transforms
    data_config = timm.data.resolve_model_data_config(model_name)

    # dimensions for DINOv3
    # 3 for 3 channels: Red, Green and Blue
    data_config['input_size'] = (3, input_size, input_size)

    transform = timm.data.create_transform(**data_config, is_training = False)
    
    return transform


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

def extract_feature(image_path, is_url):
    feature_extractor = create_feature_extractor(MODEL_NAME, DEVICE)
    transform = create_transforms(MODEL_NAME, INPUT_SIZE)

    if (is_url):
        """
        check if image_path is an Internet URL, in which case we would have
        to some more processing
        """
        response = requests.get(image_path)
        # debug code to catch 404 or 403 errors
        response.raise_for_status()
        image = Image.open(BytesIO(response.content))

    else:
        """
        image_path is a file path => Open it directly
        """
        image = Image.open(image_path)


    if image.mode == "P":
        image = image.convert("RGBA")

    image = image.convert("RGB")

    image = transform(image)
    image = image.unsqueeze(0).to(DEVICE)

    with torch.no_grad():
        embedding = feature_extractor(image)

    return embedding

def predict(image_path, is_url):
    # device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

    embedding = extract_feature(image_path, is_url)
    classifier = create_classifier(DEVICE)
    
    with open(CLASSES_PATH, "r") as f:
        classes = json.load(f)

    with torch.no_grad():
        logits = classifier(embedding)

        probs = torch.softmax(logits, dim = 1)

        confidence, pred_idx = torch.max(probs, dim = 1)

        return {
            "class": classes[pred_idx.item()], 
            "confidence": confidence.item()
        }



