import json
import random
from collections import defaultdict

'''
========================================================
Split the dataset into train and test sets
========================================================
'''

INPUT_FILE = "data/json/dataset.json"
TRAIN_SET_OUTPUT = "data/json/train_dataset.json"
TEST_SET_OUTPUT = "data/json/test_dataset.json"

SPLIT_RATIO = 0.8

# Load metadata
with open(INPUT_FILE, "r") as f:
    data = json.load(f)

# Group by (make, model, year_start, year_end)
groups = defaultdict(list)

for item in data:
    key = (
        item["make"],
        item["model"],
        item["start_year"],
        item["end_year"]
    )

    groups[key].append(item)

train_data = []
test_data = []

for key, items in groups.items():
    random.shuffle(items)

    split_idx = int(len(items)*SPLIT_RATIO)

    train_items = items[:split_idx]
    test_items = items[split_idx:]

    train_data.extend(train_items)
    test_data.extend(test_items)

# Save train and test sets
with open(TRAIN_SET_OUTPUT, "w") as f:
    json.dump(train_data, f, indent=4)

with open(TEST_SET_OUTPUT, "w") as f:
    json.dump(test_data, f, indent=4)

print(f"Total train: {len(train_data)}")
print(f"Total test: {len(test_data)}")
print(f"Groups: {len(groups)}")