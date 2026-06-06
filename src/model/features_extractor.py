import timm
import torch
from tqdm import tqdm
import faiss
import numpy as np
import torch.nn.functional as F

def extract_features(dataloader, model_name = "vit_base_patch16_dinov3"):
    '''
    return vector embeddings (features) for training and test datasets
    '''
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

    # print("=" * 16)

    # print("CUDA available:", torch.cuda.is_available())

    # if torch.cuda.is_available():
    #     print("GPU:", torch.cuda.get_device_name(0))
    #     print("Device count:", torch.cuda.device_count())

    # print("=" * 16)

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

    features_index, labels = extract_batch_features(dataloader)

    return features_index, labels


                