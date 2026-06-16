from .inference_utils import *
from pathlib import Path
from PIL import Image
from io import BytesIO

import timm
import torch
import json
import requests

# defining constants
ROOT = Path(__file__).resolve().parents[2]
INPUT_SIZE = 384

def get_transform(model_name = "vit_base_patch16_dinov3"):
    """
    Initilize and return an instance of the timm's transform class, used to pre-process input images before sending to the classifier
    """
    data_config = timm.data.resolve_model_data_config(model_name)
    data_config['input_size'] = (3, INPUT_SIZE, INPUT_SIZE)
    transform = timm.data.create_transform(**data_config, 
                                                is_training = False)

    return transform

class Predictor:
    """
    Implements the Predictor class, used to predict the model, make and year of a car image
    """

    def __init__(self, model_name = "vit_base_patch16_dinov3"):
        """
        Initialize attributes
        """
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        self.classifier = create_classifier(self.device)
        self.feature_extractor = create_feature_extractor(model_name, self.device)
        self.transform = get_transform()
        with open(ROOT / "data" / "artifacts" / "classes.json") as f:
            self.classes = json.load(f)

    def _embed_pil(self, image: Image.Image):
        if image.mode == "P":
            image = image.convert("RGBA")

        image = image.convert("RGB")
        image = self.transform(image)
        image = image.unsqueeze(0).to(self.device)

        with torch.no_grad():
            return self.feature_extractor(image)

    def extract_features(self, image_path, is_url):
        """
        Generate and return the embedding of the image
        """
        if is_url:
            response = requests.get(image_path)
            response.raise_for_status()
            image = Image.open(BytesIO(response.content))
        else:
            image = Image.open(image_path)

        return self._embed_pil(image)

    def _top_k_from_embedding(self, embedding, k):
        results = []

        with torch.no_grad():
            logits = self.classifier(embedding)
            probs = torch.softmax(logits, dim=1)
            top_preds, top_indices = torch.topk(probs, k=k, dim=1)

            for prob, idx in zip(top_preds[0], top_indices[0]):
                results.append({
                    "class": self.classes[idx.item()],
                    "confidence": prob.item()
                })

        return results

    def predict_from_image(self, image: Image.Image, k=5):
        """
        Return k car classes with the highest probabilities from a PIL image.
        """
        embedding = self._embed_pil(image)
        return self._top_k_from_embedding(embedding, k)

    def predict_top_k(self, image_path, is_url, k=5):
        """
        Return k car classes with the highest probabilities
        """
        embedding = self.extract_features(image_path, is_url)
        return self._top_k_from_embedding(embedding, k)