from pydantic import BaseModel


class ProgressUpdate(BaseModel):
    progressSeconds: int
    durationSeconds: int


class PlayResponse(BaseModel):
    videoId: int
    title: str
    playUrl: str
    lastProgressSeconds: int
    durationSeconds: int


class VideoItem(BaseModel):
    id: int
    title: str
    hls_path: str
    duration_seconds: int

    model_config = {"from_attributes": True}
