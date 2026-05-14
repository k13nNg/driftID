import os
import re
from collections import defaultdict

def audit_dataset(root_path):
    # Regex to identify our target leaf folders
    pattern = re.compile(r"([a-z0-9]+)-([a-z0-9-]+)(?:-gen)?-(\d{4})-(\d{4})")
    
    stats = []
    total_images = 0
    valid_extensions = ('.jpg', '.jpeg', '.png', '.webp', '.bmp', '.tiff')

    print(f"{'FOLDER NAME':<50} | {'COUNT':<6}")
    print("-" * 60)

    for root, dirs, files in os.walk(root_path):
        folder_name = os.path.basename(root)
        match = pattern.search(folder_name)

        if match:
            # Count images in this specific folder
            image_count = sum(1 for f in files if f.lower().endswith(valid_extensions))
            total_images += image_count
            
            stats.append({
                "folder": folder_name,
                "count": image_count
            })
            
            # Highlight potentially "suss" folders
            alert = " <-- EMPTY?" if image_count == 0 else ""
            print(f"{folder_name[:50]:<50} | {image_count:<6} {alert}")

    print("-" * 60)
    print(f"TOTAL IMAGES FOUND: {total_images}")
    print(f"TOTAL VALID FOLDERS: {len(stats)}")
    
    # Optional: Find the average to spot anomalies
    if stats:
        avg = total_images / len(stats)
        print(f"AVERAGE IMAGES PER FOLDER: {avg:.2f}")

# Run it
audit_dataset('./car-dataset-200')