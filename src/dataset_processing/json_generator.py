import os 
import re
import json

'''
------------------------------------------------------------------------------
This file generates the dataset_meta.json file from the car-dataset-200 folder
------------------------------------------------------------------------------
'''


# define the regex to look for the pattern:
#           model-make-gen-(4 digits start year)-(4 digits end year)
regex = re.compile(r"([a-z0-9]+)-([a-z0-9-]+)(?:-gen)?-(\d{4})-(\d{4})")

# initialize the list of json objects
result = []
valid_extensions = ('.jpg', '.jpeg', '.png', '.webp', '.bmp', '.tiff')
counter = 0

for (root, dirs, files) in os.walk("./car-dataset-200", topdown=True):
    # grab the current directory
    current_dir = os.path.basename(root)
    # check if the current directory matches the regex pattern
    if regex.search(current_dir) != None:
        make, model, start_year, end_year = regex.search(current_dir).groups()

        # iterate the image files
        for f in files:
            if f.lower().endswith(valid_extensions):
                result.append(
                    {
                        "make": make,
                        "model": model,
                        "start_year": start_year,
                        "end_year": end_year,
                        "image_path": os.path.join(root, f)
                    }
                )
                counter += 1
        

with open("dataset_meta.json", "w") as f:
    json.dump(result, f, indent = 4)

print(f"Succesfully added {counter} objects to dataset_meta.json")


