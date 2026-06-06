from src.model.predictor import Predictor

# image_url = "https://content-images.carmax.com/qeontfmijmzv/57EXFhA8LgZfkTMVt47yT/be10da5c5d69712e6794bb86b1b56d35/2025_Toyota_RAV4_Hybrid_XLE_Premium_53832_st2400_089.png?w=2100&fm=webp"

# image_url = "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSgVfHORQFLyUf_rNove-xUmxIskDeMJ63REz_YIMQ6S0vCyQdkBvJos4igKspvCgpqnpy8h0xM--1uckzZIxDgyoHy37-MowkF-YzvVx8&s=10"

# image_url = "https://newsroom.porsche.com/.imaging/mte/porsche-templating-theme/teaser_700x395/dam/pnr/2024/Products/992-II/0840_nevada_coupe_u-crane_AKOS0607_edit_V03-sky.jpg/jcr:content/0840_nevada_coupe_u-crane_AKOS0607_edit_V03-sky.jpg"

image_url = "https://hips.hearstapps.com/hmg-prod/images/2026-kia-sorento-101-6830c600433b3.jpg?crop=0.731xw:0.643xh;0.168xw,0.284xh&resize=1200:*"

predictor = Predictor()

results = predictor.predict_top_k(image_url, True)

for r in results:
    print(f"Class: {r['class']} | Probability: {r['confidence']}")
