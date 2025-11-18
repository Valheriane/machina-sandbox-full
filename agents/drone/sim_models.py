from dataclasses import dataclass
import math, random


@dataclass
class DroneState:
    lat: float
    lon: float
    alt: float
    speed_mps: float = 0.0
    battery_pct: float = 100.0
    status: str = "idle" # idle | flying | landing | error
    heading_deg: float = 0.0


def move_towards(state: DroneState, target_lat: float, target_lon: float,
                 dt: float, speed_mps: float = 5.0,
                 drain_factor: float = 0.005, noise_deg: float = 0.0):
    """Déplace grossièrement le drone vers un waypoint (lat/lon) en supposant terrain plat.
    NB: modèle très simplifié pour le bac à sable.
    """
    dlat = target_lat - state.lat
    dlon = target_lon - state.lon
    dist = math.hypot(dlat, dlon)
    if dist < 1e-6:
        state.speed_mps = 0.0
        return state

    # Avance proportionnellement au pas (dt) et à la vitesse
    step = (speed_mps * dt) / 111_000 # ~1 deg ≈ 111km
    if step >= dist:
        state.lat, state.lon = target_lat, target_lon
        state.speed_mps = 0.0
    else:
        state.lat += (dlat / dist) * step
        state.lon += (dlon / dist) * step
        state.speed_mps = speed_mps

    hdg = (math.degrees(math.atan2(dlon, dlat)) + 360) % 360
    if noise_deg:
        hdg = (hdg + random.uniform(-noise_deg, noise_deg)) % 360
    state.heading_deg = hdg

    state.battery_pct = max(0.0, state.battery_pct - drain_factor * speed_mps * dt)
    return state
