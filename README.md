# DriftID

# 📌 Overview

This project is an _end-to-end machine learning application_ that identifies the make and model of a car from an uploaded image.

Given a user-submitted image, the system extracts visual features using a pretrained vision backbone and classifies the car into a fine-grained category (e.g., Toyota Camry 2018, BMW X5 2021).

The goal is to demonstrate a practical computer vision pipeline combining deep feature extraction, similarity search/classification, and deployment-ready inference code.

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
