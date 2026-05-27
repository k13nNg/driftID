import timm
import torch
from tqdm import tqdm
from dataset_processing.dataset import CarImageDataset
from torch.utils.data import DataLoader
from pathlib import Path
import faiss
import numpy as np
import torch.nn.functional as F

ROOT = Path(__file__).resolve().parents[2]  # adjust if needed
TRAIN_PATH = ROOT / "train_dataset.json"
TEST_PATH = ROOT / "test_dataset.json"
FEATURES_DIR = ROOT / "features"
FEATURES_DIR.mkdir(parents=True, exist_ok=True)

def create_data_loader(batch_size = 32, model_name = "vit_base_patch16_dinov3"):
    '''
    Create and return DataLoaders for the training and test datasets
    '''

    # create transforms
    data_config = timm.data.resolve_model_data_config(model_name)
    data_config['input_size'] = (3, 384, 384)

    train_transform = timm.data.create_transform(**data_config, is_training = True)
    test_transform = timm.data.create_transform(**data_config, is_training = False)

    # create datasets
    train_dataset = CarImageDataset(str(TRAIN_PATH), transform=train_transform)
    test_dataset = CarImageDataset(str(TEST_PATH), transform=test_transform)

    train_dl = DataLoader(
        train_dataset,
        batch_size=batch_size,
        num_workers=4,
        persistent_workers=True,
        shuffle=True,
        pin_memory=True,
        prefetch_factor=4
    )

    test_dl = DataLoader(
        test_dataset,
        batch_size=batch_size,
        num_workers=4,
        persistent_workers=True,
        shuffle=False,
        pin_memory=True,
        prefetch_factor=4
    )

    return train_dl, test_dl

def extract_features(train_dl, model_name = "vit_base_patch16_dinov3"):
    '''
    return vector embeddings (features) for training and test datasets
    '''
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

    print("=" * 16)

    print("CUDA available:", torch.cuda.is_available())

    if torch.cuda.is_available():
        print("GPU:", torch.cuda.get_device_name(0))
        print("Device count:", torch.cuda.device_count())

    print("=" * 16)

    # create a feature extractor using timm
    model = timm.create_model(
        model_name=model_name,
        pretrained=True,
        num_classes = 0
    ).to(device)

    model = model.eval()

    def extract_batch_features(loader):
        index = None
        d = 0
        all_labels = []

        # pre-allocate memory block for labels => Helps with avoiding OOM
        dataset_size = len(loader.dataset)
        all_labels = np.empty(dataset_size, dtype = np.int32)
        current_idx=0
        with torch.no_grad():
            for images, labels in tqdm(loader, desc = "Extracting features"):
                images = images.to(device)
                features = model(images)
                features = F.normalize(features, p=2, dim=1)
                features = features.cpu().numpy().astype("float32")
                
                if index is None:
                    d = features.shape[1]
                    index = faiss.IndexFlatIP(d)         

                index.add(features)

                batch_size = labels.size(0)
                all_labels[current_idx : current_idx + batch_size] = labels.detach().cpu().numpy()
                current_idx += batch_size

        return index, all_labels

    train_features_index, train_labels = extract_batch_features(train_dl)

    return train_features_index, train_labels


                