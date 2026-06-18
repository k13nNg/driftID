import os
from contextlib import asynccontextmanager
from io import BytesIO
from pathlib import Path

import requests
from fastapi import FastAPI, File, HTTPException, Query, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from PIL import Image, UnidentifiedImageError
from pydantic import BaseModel, Field, HttpUrl

from src.model.predictor import Predictor

ROOT = Path(__file__).resolve().parents[2]

predictor: Predictor | None = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    global predictor
    predictor = Predictor()
    yield


app = FastAPI(lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class PredictUrlRequest(BaseModel):
    url: HttpUrl
    k: int = Field(default=5, ge=1, le=20)


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.post("/predict")
async def predict(
    file: UploadFile = File(...),
    k: int = Query(default=5, ge=1, le=20),
):
    try:
        content = await file.read()
        image = Image.open(BytesIO(content))
    except (UnidentifiedImageError, OSError):
        raise HTTPException(
            status_code=400,
            detail="Could not read image. Please upload a valid image file (JPEG, PNG, or WebP).",
        )

    try:
        predictions = predictor.predict_from_image(image, k=k)
    except Exception:
        raise HTTPException(
            status_code=500,
            detail="Inference failed. Please try again later.",
        )

    return {"predictions": predictions}


@app.post("/predict-url")
async def predict_url(body: PredictUrlRequest):
    try:
        predictions = predictor.predict_top_k(str(body.url), is_url=True, k=body.k)
    except requests.HTTPError:
        raise HTTPException(
            status_code=400,
            detail="Could not fetch image from URL. Check that the URL is valid and accessible.",
        )
    except requests.RequestException:
        raise HTTPException(
            status_code=400,
            detail="Could not reach URL. Check that the address is valid.",
        )
    except (UnidentifiedImageError, OSError):
        raise HTTPException(
            status_code=400,
            detail="URL did not point to a readable image.",
        )
    except Exception:
        raise HTTPException(
            status_code=500,
            detail="Inference failed. Please try again later.",
        )

    return {"predictions": predictions}


# Serve the built Flutter web app from the same origin as the API (single-container
# deploy, e.g. Hugging Face Spaces). When STATIC_DIR points at a real build the SPA
# is mounted at "/", so the frontend can call the API with relative URLs and no CORS.
# Mounted last so the API routes (and /docs) keep precedence. Skipped for the local
# split setup (FastAPI on :8000, Flutter dev server on :8080) where no build exists.
_static_dir = Path(os.environ.get("STATIC_DIR", ROOT / "ui" / "build" / "web"))
if _static_dir.is_dir():
    app.mount("/", StaticFiles(directory=_static_dir, html=True), name="ui")


if __name__ == "__main__":
    import uvicorn

    # Bind to PORT (Hugging Face Spaces convention) or API_PORT so each orchestrator
    # container and local runs can pick an isolated port without editing code.
    # Defaults to 8000 to match the local docs.
    port = int(os.environ.get("PORT") or os.environ.get("API_PORT", "8000"))
    uvicorn.run("src.api.server:app", host="0.0.0.0", port=port)
