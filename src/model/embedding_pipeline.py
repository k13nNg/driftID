import timm
import torch
from tqdm import tqdm
from dataset_processing.dataset import CarImageDataset
from torch.utils.data import DataLoader
from pathlib import Path

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

    train_data_loader = DataLoader(
        train_dataset,
        batch_size=batch_size,
        num_workers=4,
        persistent_workers=True,
        shuffle=True,
        pin_memory=True,
        prefetch_factor=4
    )

    test_data_loader = DataLoader(
        test_dataset,
        batch_size=batch_size,
        num_workers=4,
        persistent_workers=True,
        shuffle=False,
        pin_memory=True,
        prefetch_factor=4
    )

    return train_data_loader, test_data_loader

def extract_features(train_data_loader, test_data_loader, model_name = "vit_base_patch16_dinov3"):
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

    def dump(loader, split):
        for i, (images, labels) in enumerate(tqdm(loader, desc=f"{split} features")):
            images = images.to(device, non_blocking=True)
            features = model(images)

            torch.save(features.cpu(), FEATURES_DIR / f"{split}_batch_{i}.pt")
            torch.save(labels.cpu(), FEATURES_DIR / f"{split}_labels_{i}.pt")

    with torch.no_grad():
        dump(train_data_loader, "train")
        dump(test_data_loader, "test")