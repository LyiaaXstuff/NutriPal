"""Bounded photo uploads, orientation correction, and server-side Azure polling.

The phone never receives the Azure credential. Images/results are not persisted.
Run locally with: python -m uvicorn backend.app:app --env-file backend/.env
"""

import asyncio
import base64
from contextlib import asynccontextmanager
from dataclasses import dataclass
from io import BytesIO
import os
from urllib.parse import urlsplit
import warnings

from fastapi import FastAPI, HTTPException, Request
import httpx
from PIL import Image, ImageOps, UnidentifiedImageError
from starlette.concurrency import run_in_threadpool

MAX_UPLOAD_BYTES = 12 * 1024 * 1024
MAX_PIXELS = 30_000_000
API_VERSION = "2024-11-30"


@dataclass(frozen=True)
class Settings:
    endpoint: str = ""
    key: str = ""
    timeout_seconds: float = 90
    poll_seconds: float = 1

    @classmethod
    def from_environment(cls):
        return cls(
            endpoint=os.getenv("AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT", "").rstrip("/"),
            key=os.getenv("AZURE_DOCUMENT_INTELLIGENCE_KEY", ""),
        )

    @property
    def configured(self):
        parsed = urlsplit(self.endpoint)
        return bool(self.key and parsed.scheme == "https" and parsed.hostname
                    and not parsed.username and not parsed.password
                    and not parsed.query and not parsed.fragment
                    and parsed.path in ("", "/"))


def normalized_photo(body: bytes) -> bytes:
    try:
        with warnings.catch_warnings():
            warnings.simplefilter("error", Image.DecompressionBombWarning)
            with Image.open(BytesIO(body)) as image:
                if image.format not in {"JPEG", "PNG", "WEBP"}:
                    raise HTTPException(415, "Choose a JPEG, PNG, or WebP label photo.")
                if image.width * image.height > MAX_PIXELS:
                    raise HTTPException(413, "Photo is too large. Crop it to the label.")
                image.load()
                image = ImageOps.exif_transpose(image).convert("RGB")
                output = BytesIO()
                image.save(output, format="JPEG", quality=95)
                return output.getvalue()
    except HTTPException:
        raise
    except (UnidentifiedImageError, OSError, ValueError,
            Image.DecompressionBombWarning, Image.DecompressionBombError):
        raise HTTPException(415, "This photo could not be opened. Choose another image.") from None


class AzureLayout:
    def __init__(self, settings: Settings, client: httpx.AsyncClient):
        self.settings = settings
        self.client = client

    async def analyze(self, photo: bytes) -> dict:
        settings = self.settings
        if not settings.configured:
            raise HTTPException(503, "Online scanning is not configured on the server.")
        headers = {"Ocp-Apim-Subscription-Key": settings.key}
        url = settings.endpoint + "/documentintelligence/documentModels/prebuilt-layout:analyze"
        try:
            # One deadline includes submission, HTTP requests, delays and polling.
            async with asyncio.timeout(settings.timeout_seconds):
                response = await self.client.post(
                    url, params={"api-version": API_VERSION,
                                 "stringIndexType": "unicodeCodePoint",
                                 "outputContentFormat": "text", "pages": "1"},
                    headers=headers,
                    json={"base64Source": base64.b64encode(photo).decode("ascii")},
                )
                self._check_status(response)
                operation = response.headers.get("operation-location", "")
                origin = urlsplit(settings.endpoint)
                target = urlsplit(operation)
                # Never forward the Azure key to a redirected/unrelated host.
                if (response.status_code != 202 or target.scheme != "https"
                        or target.netloc != origin.netloc
                        or not target.path.startswith(
                            "/documentintelligence/documentModels/prebuilt-layout/analyzeResults/")):
                    raise HTTPException(502, "Online scan returned an invalid operation.")
                while True:
                    await asyncio.sleep(settings.poll_seconds)
                    response = await self.client.get(operation, headers=headers)
                    self._check_status(response)
                    payload = response.json()
                    status = payload.get("status")
                    if status == "succeeded":
                        result = payload.get("analyzeResult")
                        if not isinstance(result, dict):
                            raise HTTPException(502, "Online scan returned no document result.")
                        return result
                    if status not in {"notStarted", "running"}:
                        raise HTTPException(502, "Azure could not read this photo. Retake the label.")
        except (TimeoutError, httpx.TimeoutException):
            raise HTTPException(504, "Online scan timed out. Please try again.") from None
        except (httpx.HTTPError, ValueError, TypeError, AttributeError):
            raise HTTPException(502, "Online scanning is temporarily unavailable.") from None

    @staticmethod
    def _check_status(response):
        if response.status_code == 429:
            raise HTTPException(503, "Online scanning is busy. Please try again shortly.")
        if response.status_code >= 300:
            # Do not expose upstream bodies, keys, request URLs, or account details.
            raise HTTPException(502, "Online scanning could not complete this request.")


def create_app(settings: Settings | None = None, *, transport=None):
    settings = settings or Settings.from_environment()

    @asynccontextmanager
    async def lifespan(app):
        async with httpx.AsyncClient(timeout=20, follow_redirects=False,
                                     transport=transport) as client:
            app.state.azure = AzureLayout(settings, client)
            app.state.capacity = asyncio.Semaphore(2)
            yield

    app = FastAPI(title="NutriPal scanning service", lifespan=lifespan)

    @app.get("/health")
    async def health():
        return {"status": "ok", "azure_configured": settings.configured}

    @app.post("/api/v1/nutrition/analyze")
    async def analyze(request: Request):
        if not settings.configured:
            raise HTTPException(503, "Online scanning is not configured on the server.")
        content_type = request.headers.get("content-type", "").split(";")[0]
        if content_type not in {"image/jpeg", "image/png", "image/webp", "application/octet-stream"}:
            raise HTTPException(415, "Upload a label photo as an image.")
        body = bytearray()
        async for chunk in request.stream():
            if len(body) + len(chunk) > MAX_UPLOAD_BYTES:
                raise HTTPException(413, "Photo exceeds 12 MB. Crop it to the label.")
            body.extend(chunk)
        if not body:
            raise HTTPException(400, "Choose a label photo first.")
        # Limit local concurrency; this endpoint is for local development. Use
        # authenticated ingress and per-user quotas before public deployment.
        try:
            await asyncio.wait_for(app.state.capacity.acquire(), timeout=0.1)
        except TimeoutError:
            raise HTTPException(503, "Online scanning is busy. Please try again shortly.") from None
        try:
            photo = await run_in_threadpool(normalized_photo, bytes(body))
            result = await app.state.azure.analyze(photo)
            return {"provider": "azure-layout", "analyzeResult": result}
        finally:
            app.state.capacity.release()

    return app


app = create_app()
