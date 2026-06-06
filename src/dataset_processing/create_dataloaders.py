import timm

from torch.utils.data import DataLoader
from dataset_processing.car_ds_class import CarImageDataset
from dataset_processing.car_ds_class import CarImageDataset
from torch.utils.data import TensorDataset
from torch.utils.data import DataLoader

def create_features_dl(train_features, train_labels, batch_size = 32):
    '''
    Create and return DataLoaders for the training and test features
    '''

    train_ds = TensorDataset(train_features, train_labels)

    train_dl = DataLoader(
        train_ds,
        batch_size=batch_size,
        shuffle=True,
        num_workers = 0,
        pin_memory = True
    )

    return train_dl

def create_train_test_dl(train_ds_path, 
                       test_ds_path, 
                       batch_size = 32, 
                       model_name = "vit_base_patch16_dinov3"):
    '''
    Create and return DataLoaders for the training and test datasets
    '''

    # create transforms
    data_config = timm.data.resolve_model_data_config(model_name)

    # dimensions for DINOv3
    data_config['input_size'] = (3, 384, 384)

    train_transform = timm.data.create_transform(**data_config, is_training = True)
    test_transform = timm.data.create_transform(**data_config, is_training = False)

    # create datasets
    train_dataset = CarImageDataset(train_ds_path, transform=train_transform)
    test_dataset = CarImageDataset(test_ds_path, transform=test_transform)

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