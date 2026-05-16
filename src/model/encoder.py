import timm
import torch
from tqdm import tqdm
from car_image_dataset_class import CarImageDataset
from torch.utils.data import DataLoader

def create_data_loader(batch_size = 32, model_name = "vit_base_patch16_dinov3"):
    '''
    Create and return DataLoaders for the training and test datasets
    '''

    # create transforms
    data_config = timm.data.resolve_model_data_config(model_name)
    data_config['input_size'] = (3, 528, 528)

    train_transform = timm.data.create_transform(**data_config, is_training = True)
    test_transform = timm.data.create_transform(**data_config, is_training = False)

    # create datasets
    train_dataset = CarImageDataset("train_dataset.json", transform=train_transform)
    test_dataset = CarImageDataset("test_dataset.json", transform=test_transform)

    train_data_loader = DataLoader(
        train_dataset,
        batch_size=batch_size,
        num_workers=2,
        shuffle=True
    )

    test_data_loader = DataLoader(
        test_dataset,
        batch_size=batch_size,
        num_workers=2,
        shuffle=False
    )

    return train_data_loader, test_data_loader, train_dataset.class_name_to_id, train_dataset.id_to_class_name

def extract_features(train_data_loader, test_data_loader, model_name = "vit_base_patch16_dinov3"):
    '''
    return vector embeddings (features) for training and test datasets
    '''
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

    # create a feature extractor using timm
    model = timm.create_model(
        model_name=model_name,
        pretrained=True,
        num_classes = 0
    ).to(device)

    model = model.eval()

    def extract_batch_features(loader):
        all_features = []
        all_labels = []

        with torch.no_grad():
            for images, labels in tqdm(loader, desc="Extracting features"):
                images = images.to(device)
                features = model(images)
                all_features.append(features.cpu())
                all_labels.append(labels)

        return torch.cat(all_features, dim=0), torch.cat(all_labels, dim=0)

    train_features, train_labels = extract_batch_features(train_data_loader)
    test_features, test_labels = extract_batch_features(test_data_loader)

    return train_features, train_labels, test_features, test_labels

train_data_loader, test_data_loader, class_name_to_id, id_to_class_name = create_data_loader()

train_features, _, test_features, _ = extract_features(train_data_loader, test_data_loader)

print(train_features)