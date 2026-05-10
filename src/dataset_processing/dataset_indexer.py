import os
import json
from pathlib import Path

DATASET_DIR = "dataset"
OUTPUT_FILE = "cars.json"

CURRENT_YEAR = 2026

results = []

for root, _, files in os.walk(DATASET_DIR):

    for file in files:

        path = Path(root) / file
        stem = path.stem.replace("–", "-")
        ext = path.suffix.lower()

        parts = stem.split("-")

        try:
            image_id = parts[-1]

            # ---- detect structure ----
            if "gen" in parts:
                gen_index = parts.index("gen")

                make = parts[0].lower()
                model = "-".join(parts[1:gen_index]).lower()

                start = parts[gen_index + 1]
                end = parts[gen_index + 2] if len(parts) > gen_index + 2 else start

            else:
                make = parts[0].lower()
                model = "-".join(parts[1:-3]).lower()

                start = parts[-3]
                end = parts[-2]

            # ---- normalize years ----
            start_year = int(start)

            if end == "present":
                end_year = CURRENT_YEAR
            else:
                end_year = int(end)

            # ---- single record per image (IMPORTANT FIX) ----
            results.append({
                "make": make,
                "model": model,
                "year_start": start_year,
                "year_end": end_year,
                "filepath": str(path),
                "filename": file
            })

        except Exception as e:
            print(f"Skipping invalid filename: {file}")
            print(f"Reason: {e}")

with open(OUTPUT_FILE, "w") as f:
    json.dump(results, f, indent=4)

print(f"Saved {len(results)} entries.")