# 🚗 DriftID

# 🚀 Overview

This project is an _end-to-end machine learning application_ that identifies the make and model of a car from an uploaded image.

Given a user-submitted image, the system extracts visual features using a pretrained vision backbone and classifies the car into a fine-grained category (e.g., Toyota Camry 2018, BMW X5 2021).

The goal is to demonstrate a practical computer vision pipeline combining deep feature extraction, similarity search/classification, and deployment-ready inference code.

# 📊 Dataset

This project uses the Car Make, Model, and Generation dataset from Kaggle, which contains labeled images of vehicles across multiple manufacturers, models, and production years.

  - 📦 Dataset: Car Make, Model, and Generation
  - 🔗 Source: https://www.kaggle.com/datasets/riotulab/car-make-model-and-generation
  - 🚗 Content: 41,521 images of cars annotated with:
    - Make (e.g., Toyota, BMW, Audi)
    - Model (e.g., Camry, X5, A4)
    - Generation / Year variant (in some classes)

## 🧠 Dataset Usage
The dataset was used to train a supervised classification model on top of deep visual embeddings extracted from a pretrained vision backbone.

Each image was processed into:

  - A normalized input tensor for feature extraction
  - A corresponding label representing the car class (make + model combination)

## ⚙️ Preprocessing Steps

To ensure consistency and improve model performance, the following preprocessing steps were applied:

  - Resizing images to a fixed resolution (384x384 to be consistent with DINOv3's input dimension)
  - Normalization and augmentation using `timm` data configs

Further, the dataset was splitted into `training` set and `testing` set, with a ratio of 80% `training` set and 20% `testing` set
 
## 📌 Notes
  - The dataset is fine-grained, making classification challenging due to high visual similarity between car models.
  - Some classes have limited samples, introducing mild class imbalance.
  - The dataset structure makes it suitable for both:
    - Standard classification
    - Embedding-based retrieval approaches (e.g., FAISS)

# ✨ Key Features
  - 📷 Image upload interface for real-time inference
  - 🧠 Deep learning-based feature extractor ([DINOv3](https://arxiv.org/abs/2508.10104) Vision Transformer backbone)
  - 🔍 Classification over fine-grained car labels 
  - 🧩 Modular design (feature extractor + classifier separated)

# 🧠 System Architecture

At a high level, the system works as follows:
  1. Input image uploaded by user
  2. Preprocessing pipeline
  3. Feature extraction (DINOv3 Vision Transformer)
  4. Classification layer (Linear Classifier Neural Network trained on car embeddings
  5: Prediction output (Top-k predicted car makes/models + confidence scores)

<div align="center">
  <img width="500" height="721" alt="image" src="https://github.com/user-attachments/assets/8cb1f698-8551-4009-81c4-3673bfc3d4c2" />
</div>

# ⚙️ Model Details
  - **Backbone:** Vision Transformer (ViT) / DINOv3 pretrained model
  - **Embedding size:** `384` dimensional feature vector (For optimal training time)
  - **Classifier:** Linear layer trained on frozen embeddings (Following the strategy outlined in [this article](https://pub.towardsai.net/harness-dinov2-embeddings-for-accurate-image-classification-f102dfd35c51))
  - **Loss function:** Cross-entropy loss
  - **Training strategy:** Feature extraction + supervised fine-tuning on labeled car dataset

# 📚 Citations
  - https://pub.towardsai.net/harness-dinov2-embeddings-for-accurate-image-classification-f102dfd35c51
