from collections import defaultdict
import os
import json
from torch.utils import Dataset
from PIL import Image

class CarImageDataset(Dataset):
    '''
    Custom Dataset class to process JSON objects from the metadata file
    '''
    def __init__(self, json_file, transform = None):
        with open(json_file, "r") as f:
            self.data = json.load(f)

        self.transform = transform
        
        # classes for prediction later
        unique_class_strings = [
            f"{item['make']}_{item['model']}_{item['start_year']}_{item['end_year']}"
            for item in self.data
        ]

        self.classes = sorted(list(set(unique_class_strings)))

        # index labels
        self.class_name2id, self.id2class_name= defaultdict(list)

        for i, class_name in enumerate(self.classes):
            self.class_name2id[class_name] = i
            self.id2class_name[i] = class_name
    
    def __len__(self):
        return len(self.data)
    
    def __getitem__(self, idx):
        item = self.data[idx]
        image = Image.open(item["image_path"])
        class_name = self.id2class_name[f"{item['make']}_{item['model']}_{item['start_year']}_{item['end_year']}"]

        if self.transform:
            image = self.transform(image)

        return image, class_name