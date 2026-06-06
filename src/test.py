from src.model.infer import predict

# image_url = "https://di-uploads-pod24.dealerinspire.com/classicchevy/uploads/2019/09/2019-cheverolet-impala-Hero-Image.png"

image_url = "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSgVfHORQFLyUf_rNove-xUmxIskDeMJ63REz_YIMQ6S0vCyQdkBvJos4igKspvCgpqnpy8h0xM--1uckzZIxDgyoHy37-MowkF-YzvVx8&s=10"

print(predict(image_url, True))