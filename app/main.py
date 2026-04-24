from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db import Base, SessionLocal, engine
from app.models import User, Video, VideoPlayProgress
from app.schemas import PlayResponse, ProgressUpdate, VideoItem

Base.metadata.create_all(bind=engine)

# Demo user: user_id=1, username="test"
CURRENT_USER_ID = 1
DEMO_USERNAME = "test"


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def ensure_demo_user(db: Session) -> None:
    """Create the demo user if it does not exist yet."""
    user = db.get(User, CURRENT_USER_ID)
    if not user:
        user = User(id=CURRENT_USER_ID, username=DEMO_USERNAME)
        db.add(user)
        db.commit()


@asynccontextmanager
async def lifespan(application: FastAPI):
    db = SessionLocal()
    try:
        ensure_demo_user(db)
    finally:
        db.close()
    yield


app = FastAPI(title="Video Streaming Service", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/api/health")
def health():
    return {"status": "ok"}


@app.get("/api/videos", response_model=list[VideoItem])
def list_videos(db: Session = Depends(get_db)):
    videos = db.execute(select(Video)).scalars().all()
    return videos


@app.get("/api/videos/{video_id}/play", response_model=PlayResponse)
def get_play_info(video_id: int, db: Session = Depends(get_db)):
    video = db.get(Video, video_id)
    if not video:
        raise HTTPException(status_code=404, detail="Video not found")

    progress = db.execute(
        select(VideoPlayProgress).where(
            VideoPlayProgress.user_id == CURRENT_USER_ID,
            VideoPlayProgress.video_id == video_id,
        )
    ).scalar_one_or_none()

    last_progress = progress.progress_seconds if progress else 0

    return PlayResponse(
        videoId=video.id,
        title=video.title,
        playUrl=video.hls_path,
        lastProgressSeconds=last_progress,
        durationSeconds=video.duration_seconds,
    )


@app.post("/api/videos/{video_id}/progress")
def save_progress(
    video_id: int, payload: ProgressUpdate, db: Session = Depends(get_db)
):
    video = db.get(Video, video_id)
    if not video:
        raise HTTPException(status_code=404, detail="Video not found")

    progress = db.execute(
        select(VideoPlayProgress).where(
            VideoPlayProgress.user_id == CURRENT_USER_ID,
            VideoPlayProgress.video_id == video_id,
        )
    ).scalar_one_or_none()

    if progress:
        progress.progress_seconds = payload.progressSeconds
        progress.duration_seconds = payload.durationSeconds
    else:
        progress = VideoPlayProgress(
            user_id=CURRENT_USER_ID,
            video_id=video_id,
            progress_seconds=payload.progressSeconds,
            duration_seconds=payload.durationSeconds,
        )
        db.add(progress)

    db.commit()
    return {"success": True}
