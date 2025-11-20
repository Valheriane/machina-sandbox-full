from fastapi import FastAPI, HTTPException
from typing import List
from sqlmodel import select
from models import Drone, DroneCreate, DroneRead, CommandRequest, DroneUpdate, get_session
from manager import FleetManager
from config import get_config
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="Fleet API", version="0.1.0")




app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173","http://localhost:8085",],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

cfg = get_config()
fleet = FleetManager()

# --- tests app  ---

@app.get("/health")
def health():
    return {"status": "ok"}

# --- CRUD drones ---

@app.post("/drones", response_model=DroneRead)
def create_drone(body: DroneCreate):
    with get_session(cfg["database_url"]) as s:
        if s.get(Drone, body.id):
            raise HTTPException(400, "Drone already exists")
        d = Drone(
            id=body.id,
            topic_prefix=body.topic_prefix,
            start_lat=body.start_lat,
            start_lon=body.start_lon,
            start_alt=body.start_alt,
            publish_interval_sec=body.publish_interval_sec,
            cruise_speed_mps=body.cruise_speed_mps,
            battery_drain=body.battery_drain,
            heading_noise=body.heading_noise,
            status="stopped",
        )
        s.add(d); s.commit(); s.refresh(d)
        return DroneRead(**d.model_dump())

@app.get("/drones", response_model=List[DroneRead])
def list_drones():
    with get_session(cfg["database_url"]) as s:
        rows = s.exec(select(Drone)).all()
        # met à jour statut en mémoire si besoin
        out = []
        for d in rows:
            d.status = "running" if (d.id in fleet.workers and fleet.workers[d.id].is_running()) else "stopped"
            out.append(DroneRead(**d.model_dump()))
        return out

@app.get("/drones/{drone_id}", response_model=DroneRead)
def get_drone(drone_id: str):
    with get_session(cfg["database_url"]) as s:
        d = s.get(Drone, drone_id)
        if not d:
            raise HTTPException(404, "Not found")
        d.status = "running" if (drone_id in fleet.workers and fleet.workers[drone_id].is_running()) else "stopped"
        return DroneRead(**d.model_dump())

@app.delete("/drones/{drone_id}")
def delete_drone(drone_id: str):
    with get_session(cfg["database_url"]) as s:
        d = s.get(Drone, drone_id)
        if not d:
            raise HTTPException(404, "Not found")
        # stoppe si en cours
        fleet.stop(drone_id)
        s.delete(d); s.commit()
        return {"ok": True}
    
@app.patch("/drones/{drone_id}", response_model=DroneRead)
def update_drone(drone_id: str, body: DroneUpdate):
    with get_session(cfg["database_url"]) as s:
        d = s.get(Drone, drone_id)
        if not d:
            raise HTTPException(404, "Not found")

        # ne met à jour que les champs fournis
        data = body.model_dump(exclude_unset=True)
        for k, v in data.items():
            setattr(d, k, v)

        s.add(d); s.commit(); s.refresh(d)

        # remettre à jour le status calculé
        d.status = "running" if (drone_id in fleet.workers and fleet.workers[drone_id].is_running()) else "stopped"
        return DroneRead(**d.model_dump())

# --- Start/Stop ---

@app.post("/drones/{drone_id}/start")
def start_drone(drone_id: str):
    with get_session(cfg["database_url"]) as s:
        d = s.get(Drone, drone_id)
        if not d:
            raise HTTPException(404, "Not found")
        fleet.start(d)
        return {"ok": True, "status": "running"}

@app.post("/drones/{drone_id}/stop")
def stop_drone(drone_id: str):
    fleet.stop(drone_id)
    return {"ok": True, "status": "stopped"}

# --- Commandes (API signe et publie sur MQTT) ---

@app.post("/drones/{drone_id}/cmd")
def command_drone(drone_id: str, body: CommandRequest):
    with get_session(cfg["database_url"]) as s:
        d = s.get(Drone, drone_id)
        if not d:
            raise HTTPException(404, "Not found")
        payload = {"cmd": body.cmd}
        if body.args:
            payload["args"] = body.args
        topic, envelope = fleet.publish_cmd(d.topic_prefix, d.id, payload)
        return {"ok": True, "topic": topic, "envelope": envelope}
