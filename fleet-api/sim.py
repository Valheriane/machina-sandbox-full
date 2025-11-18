"""
Boucle simulateur d'UN drone : tourne dans un thread.
- Publie la télémétrie périodiquement.
- S'abonne aux commandes sur .../commands et vérifie la signature HMAC.
- Met à jour l'état (takeoff/land/goto/rth/ping).
"""

import time, json, threading, math, random
from dataclasses import dataclass
from typing import Optional, Tuple
import paho.mqtt.client as mqtt
from security import verify

@dataclass
class DroneState:
    lat: float
    lon: float
    alt: float
    speed_mps: float = 0.0
    battery_pct: float = 100.0
    status: str = "idle"
    heading_deg: float = 0.0

def move_towards(state: DroneState, target_lat: float, target_lon: float,
                 dt: float, speed_mps: float,
                 drain_factor: float, noise_deg: float):
    dlat = target_lat - state.lat
    dlon = target_lon - state.lon
    dist = math.hypot(dlat, dlon)
    if dist < 1e-9:
        state.speed_mps = 0.0
        return
    step = (speed_mps * dt) / 111_000.0
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

class DroneWorker:
    """
    Un worker = un simulateur de drone isolé,
    alimenté par des paramètres (caractéristiques) et lié à un broker MQTT.
    """
    def __init__(
        self,
        drone_id: str,
        topic_prefix: str,
        mqtt_host: str,
        mqtt_port: int,
        shared_secret: str,
        start_lat: float, start_lon: float, start_alt: float,
        publish_interval_sec: float,
        cruise_speed_mps: float,
        battery_drain: float,
        heading_noise: float,
    ):
        self.drone_id = drone_id
        self.topic_prefix = topic_prefix
        self.mqtt_host = mqtt_host
        self.mqtt_port = mqtt_port
        self.shared_secret = shared_secret
        self.publish_interval = publish_interval_sec
        self.cruise_speed = cruise_speed_mps
        self.battery_drain = battery_drain
        self.heading_noise = heading_noise

        self.state = DroneState(lat=start_lat, lon=start_lon, alt=start_alt)
        self._waypoint: Optional[Tuple[float, float]] = None
        self._running = threading.Event()
        self._thread: Optional[threading.Thread] = None

        # Topics
        self.base = f"{self.topic_prefix}/drone/{self.drone_id}"
        self.t_telemetry = f"{self.base}/telemetry"
        self.t_events = f"{self.base}/events"
        self.t_commands = f"{self.base}/commands"

        # MQTT client
        self.client = mqtt.Client(client_id=self.drone_id)   # paho 1.x
        self.client.on_connect = self._on_connect
        self.client.on_message = self._on_message

    # --- MQTT callbacks ---

    def _on_connect(self, client, userdata, flags, rc):
        print(f"[{self.drone_id}] MQTT connected rc={rc}")
        client.subscribe(self.t_commands)
        client.publish(self.t_events, json.dumps({
            "type": "status", "message": "connected", "ts": time.time()
        }), qos=1)

    def _on_message(self, client, userdata, msg):
        try:
            data = json.loads(msg.payload.decode())
        except Exception as e:
            print(f"[{self.drone_id}] invalid JSON cmd: {e}")
            return
        sig = data.get("sig")
        payload = data.get("payload")
        if not isinstance(payload, dict) or not isinstance(sig, str):
            print(f"[{self.drone_id}] missing payload/sig")
            return
        if not verify(payload, sig, self.shared_secret):
            print(f"[{self.drone_id}] signature invalid")
            return

        cmd = payload.get("cmd")
        args = payload.get("args") or {}
        print(f"[{self.drone_id}] CMD {cmd} {args}")

        if cmd == "ping":
            client.publish(self.t_events, json.dumps({"type": "pong", "ts": time.time()}))
        elif cmd == "takeoff":
            self.state.status = "flying"
            self.state.alt = max(self.state.alt, float(args.get("alt", 10.0)))
        elif cmd == "land":
            self.state.status = "landing"
            self.state.alt = 0.0
            self._waypoint = None
        elif cmd == "goto":
            self.state.status = "flying"
            self._waypoint = (float(args["lat"]), float(args["lon"]))
            self.state.alt = float(args.get("alt", self.state.alt))
        elif cmd == "rth":
            # "home" = point de départ initial (on n'a pas stocké à part : c'est l'état actuel si tu veux)
            # Pour un vrai RTH, tu peux stocker start_lat/lon comme attributs et les réutiliser ici.
            pass
        else:
            print(f"[{self.drone_id}] unknown cmd")

    # --- loop ---

    def _loop(self):
        self.client.connect(self.mqtt_host, self.mqtt_port, keepalive=30)
        self.client.loop_start()
        self._running.set()

        try:
            while self._running.is_set():
                if self.state.status == "flying" and self._waypoint is not None:
                    move_towards(
                        self.state, self._waypoint[0], self._waypoint[1],
                        dt=self.publish_interval,
                        speed_mps=self.cruise_speed,
                        drain_factor=self.battery_drain,
                        noise_deg=self.heading_noise
                    )
                    # arrivé ?
                    if abs(self.state.lat - self._waypoint[0]) < 1e-5 and abs(self.state.lon - self._waypoint[1]) < 1e-5:
                        self._waypoint = None
                        self.state.status = "idle"

                payload = {
                    "drone_id": self.drone_id,
                    "ts": time.time(),
                    "position": {"lat": self.state.lat, "lon": self.state.lon, "alt": self.state.alt},
                    "speed_mps": self.state.speed_mps,
                    "battery_pct": self.state.battery_pct,
                    "status": self.state.status,
                    "heading_deg": self.state.heading_deg,
                }
                self.client.publish(self.t_telemetry, json.dumps(payload), qos=0)
                time.sleep(self.publish_interval)
        finally:
            self.client.loop_stop()
            self.client.disconnect()
            print(f"[{self.drone_id}] stopped")

    # --- public API ---

    def start(self):
        if self._thread and self._thread.is_alive():
            return
        self._thread = threading.Thread(target=self._loop, daemon=True)
        self._thread.start()

    def stop(self):
        self._running.clear()
        if self._thread:
            self._thread.join(timeout=2.0)

    def is_running(self) -> bool:
        return self._thread is not None and self._thread.is_alive()
