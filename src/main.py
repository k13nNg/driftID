import torch
import faiss
import numpy as np
import timm
import torch.nn.functional as F
from PIL import Image
from dataset_processing.dataset import CarImageDataset
import requests
from io import BytesIO

index = faiss.read_index("train_index")
labels = np.load("train_labels.npy")

# test_image_filepath = "./car-dataset-200/hyundai/hyundai-accent/hyundai-accent-gen-2006-2011/hyundai-accent-gen-2006-2011-87.jpg"

url = "https://images.hgmsites.net/lrg/2025-audi-q5-s-line-premium-55-tfsi-e-quattro-angular-front-exterior-view_100960946_l.webp"

response = requests.get(url)
test_image = Image.open(BytesIO(response.content)).convert("RGB")

K = 5
MODEL_NAME = "vit_base_patch16_dinov3"

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

model = timm.create_model(
    model_name= MODEL_NAME,
    pretrained=True,
    num_classes = 0
).to(device)

model = model.eval()

data_config = timm.data.resolve_model_data_config(model)
transform = timm.data.create_transform(**data_config, is_training=False)

# test_image = Image.open(test_image_filepath).convert("RGB")
test_image = transform(test_image).unsqueeze(0).to(device)

with torch.no_grad():
    features = model(test_image)
    features = F.normalize(features, p=2, dim=1)

features = features.cpu().numpy().astype("float32")

_, pred_indices = index.search(features, K)

train_dl = CarImageDataset("dataset_meta.json")

pred_class_ids = labels[pred_indices[0]]

for class_id in pred_class_ids:
    print(train_dl.id_to_class_name[int(class_id)])

print(pred_indices)