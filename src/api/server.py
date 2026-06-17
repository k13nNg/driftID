import os
from contextlib import asynccontextmanager
from io import BytesIO

import requests
from fastapi import FastAPI, File, HTTPException, Query, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from PIL import Image, UnidentifiedImageError
from pydantic import BaseModel, Field, HttpUrl

from src.model.predictor import Predictor

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


if __name__ == "__main__":
    import uvicorn

    # Bind to API_PORT so each orchestrator container (and local runs) can run on
    # an isolated port without editing code. Defaults to 8000 to match docs.
    uvicorn.run(
        "src.api.server:app",
        host="0.0.0.0",
        port=int(os.environ.get("API_PORT", "8000")),
    )
