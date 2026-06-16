import sys
from pathlib import Path

import requests

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

import pytest
from fastapi.testclient import TestClient

import src.api.server as server


class FakePredictor:
    """Stand-in for the real Predictor so tests avoid loading the DINOv3 model."""

    PREDICTIONS = [
        {"class": "porsche_cayenne-gen_2017_2021", "confidence": 0.58},
        {"class": "landrover_rangeroversport-gen_2013_2021", "confidence": 0.27},
        {"class": "chevrolet_traverse-gen_2012_2017", "confidence": 0.15},
        {"class": "bmw_x5-gen_2019_2023", "confidence": 0.10},
        {"class": "audi_q7-gen_2015_2019", "confidence": 0.05},
    ]

    def __init__(self, *args, **kwargs):
        pass

    def predict_from_image(self, image, k=5):
        return self.PREDICTIONS[:k]

    def predict_top_k(self, image_path, is_url, k=5):
        if "broken" in image_path:
            raise requests.HTTPError("404 Not Found")
        if "unreachable" in image_path:
            raise requests.ConnectionError("could not connect")
        return self.PREDICTIONS[:k]


@pytest.fixture
def client(monkeypatch):
    monkeypatch.setattr(server, "Predictor", FakePredictor)
    with TestClient(server.app) as test_client:
        yield test_client
