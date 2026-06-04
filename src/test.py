import torch
import faiss
import numpy as np
import timm
import torch.nn.functional as F
from PIL import Image
from dataset_processing.car_ds_class import CarImageDataset
import requests
from io import BytesIO

index = faiss.read_index("train_index")
labels = np.load("train_labels.npy")

# test_image_filepath = "./car-dataset-200/hyundai/hyundai-accent/hyundai-accent-gen-2006-2011/hyundai-accent-gen-2006-2011-87.jpg"

url = "https://di-enrollment-api.s3.amazonaws.com/lexus/models/2026/rxphev/trims/RX_HYBRID.png"

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

distance, pred_indices = index.search(features, K)

vehicle_lookup_table = CarImageDataset("dataset_meta.json").id_to_class_name

pred_class_ids = labels[pred_indices[0]]

for dist, class_id in zip(distance[0], pred_class_ids):
    print(
        f"Make and Model: {vehicle_lookup_table[int(class_id)]}\n"
        f"Distance: {dist}\n"
    )