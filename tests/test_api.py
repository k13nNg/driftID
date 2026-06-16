from io import BytesIO

from PIL import Image


def _png_bytes(color=(120, 120, 120)):
    buf = BytesIO()
    Image.new("RGB", (32, 32), color).save(buf, format="PNG")
    buf.seek(0)
    return buf


def test_health(client):
    res = client.get("/health")
    assert res.status_code == 200
    assert res.json() == {"status": "ok"}


def test_predict_returns_top_k(client):
    res = client.post(
        "/predict?k=3",
        files={"file": ("car.png", _png_bytes(), "image/png")},
    )
    assert res.status_code == 200
    predictions = res.json()["predictions"]
    assert len(predictions) == 3
    for row in predictions:
        assert set(row) == {"class", "confidence"}
    confidences = [row["confidence"] for row in predictions]
    assert confidences == sorted(confidences, reverse=True)


def test_predict_default_k_is_five(client):
    res = client.post("/predict", files={"file": ("car.png", _png_bytes(), "image/png")})
    assert res.status_code == 200
    assert len(res.json()["predictions"]) == 5


def test_predict_rejects_non_image(client):
    res = client.post(
        "/predict",
        files={"file": ("notes.txt", BytesIO(b"this is not an image"), "text/plain")},
    )
    assert res.status_code == 400
    assert "image" in res.json()["detail"].lower()


def test_predict_rejects_out_of_range_k(client):
    res = client.post(
        "/predict?k=99",
        files={"file": ("car.png", _png_bytes(), "image/png")},
    )
    assert res.status_code == 422


def test_predict_url_returns_top_k(client):
    res = client.post(
        "/predict-url",
        json={"url": "https://example.com/car.jpg", "k": 2},
    )
    assert res.status_code == 200
    predictions = res.json()["predictions"]
    assert len(predictions) == 2
    assert predictions[0]["class"]


def test_predict_url_handles_unfetchable_image(client):
    res = client.post(
        "/predict-url",
        json={"url": "https://example.com/broken.jpg"},
    )
    assert res.status_code == 400
    assert "fetch" in res.json()["detail"].lower()


def test_predict_url_handles_unreachable_host(client):
    res = client.post(
        "/predict-url",
        json={"url": "https://unreachable.example.com/car.jpg"},
    )
    assert res.status_code == 400


def test_predict_url_rejects_invalid_url(client):
    res = client.post("/predict-url", json={"url": "notaurl"})
    assert res.status_code == 422
