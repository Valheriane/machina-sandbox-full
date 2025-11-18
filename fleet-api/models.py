# Modèles SQLModel (SQLite) + schémas API.
from typing import Optional, List
from sqlmodel import Field, SQLModel, create_engine, Session, select
from pydantic import BaseModel

# --- DB models ---

class Drone(SQLModel, table=True):
    id: str = Field(primary_key=True)            # ex: "drone-001"
    topic_prefix: str = "lab"
    start_lat: float = 48.8566
    start_lon: float = 2.3522
    start_alt: float = 0.0
    publish_interval_sec: float = 1.0
    cruise_speed_mps: float = 8.0
    battery_drain: float = 0.005
    heading_noise: float = 0.0
    status: str = "stopped"                      # "stopped" | "running"

# --- API schemas ---

class DroneCreate(BaseModel):
    id: str
    topic_prefix: str = "lab"
    start_lat: float = 48.8566
    start_lon: float = 2.3522
    start_alt: float = 0.0
    publish_interval_sec: float = 1.0
    cruise_speed_mps: float = 8.0
    battery_drain: float = 0.005
    heading_noise: float = 0.0
    
class DroneUpdate(SQLModel):
    topic_prefix: Optional[str] = None
    start_lat: Optional[float] = None
    start_lon: Optional[float] = None
    start_alt: Optional[float] = None
    publish_interval_sec: Optional[float] = None
    cruise_speed_mps: Optional[float] = None
    battery_drain: Optional[float] = None
    heading_noise: Optional[float] = None

class DroneRead(BaseModel):
    id: str
    topic_prefix: str
    start_lat: float
    start_lon: float
    start_alt: float
    publish_interval_sec: float
    cruise_speed_mps: float
    battery_drain: float
    heading_noise: float
    status: str

class CommandRequest(BaseModel):
    cmd: str  # "ping" | "takeoff" | "land" | "goto" | "rth"
    args: Optional[dict] = None

# --- DB helpers ---

_engine = None

def get_engine(database_url: str):
    global _engine
    if _engine is None:
        _engine = create_engine(database_url, echo=False)
        SQLModel.metadata.create_all(_engine)
    return _engine

def get_session(database_url: str) -> Session:
    engine = get_engine(database_url)
    return Session(engine)
