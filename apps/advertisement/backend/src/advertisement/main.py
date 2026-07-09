from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from advertisement.api.generated_video_router import router as generated_video_router
from advertisement.api.prompt_router import router as prompt_router
from advertisement.api.upload_router import router as upload_router
from advertisement.api.video_router import router as video_router
from advertisement.config import settings


@asynccontextmanager
async def lifespan(app: FastAPI):
    yield


app = FastAPI(
    title=settings.app_name,
    version="0.1.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
async def health_check():
    return {"status": "ok"}


app.include_router(upload_router, prefix=f"{settings.api_prefix}/uploads", tags=["uploads"])
app.include_router(video_router, prefix=f"{settings.api_prefix}/videos", tags=["videos"])
app.include_router(prompt_router, prefix=f"{settings.api_prefix}/prompts", tags=["prompts"])
app.include_router(
    generated_video_router, prefix=f"{settings.api_prefix}/generated-videos", tags=["generated-videos"]
)
