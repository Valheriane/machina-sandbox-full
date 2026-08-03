import json
import os
import time
import threading
from typing import Optional


import paho.mqtt.client as mqtt


from config import get_config
from security import verify
from sim_models import DroneState, move_towards


cfg = get_config()


TOPIC_BASE = f"{cfg['mqtt']['topic_prefix']}/drone/{cfg['drone_id']}"
TOPIC_TELEMETRY = f"{TOPIC_BASE}/telemetry"
TOPIC_EVENTS = f"{TOPIC_BASE}/events"
TOPIC_COMMANDS = f"{TOPIC_BASE}/commands" # sous-topic unique, cmd via payload JSON


state = DroneState(
lat=cfg["start"]["lat"],
lon=cfg["start"]["lon"],
alt=cfg["start"]["alt"],
)


_waypoint: Optional[tuple[float, float]] = None
_running = True


def on_connect(client, userdata, flags, rc, properties=None):
    print("[MQTT] Connected with result code", rc)
    client.subscribe(TOPIC_COMMANDS)
    client.publish(TOPIC_EVENTS, json.dumps({
        "type": "status",
        "message": "connected",
        "ts": time.time(),
    }), qos=1)

def on_message(client, userdata, msg):
    global _waypoint, state
    try:
        data = json.loads(msg.payload.decode())
    except Exception as e:
        print("[CMD] Invalid JSON:", e)
        return


    signature = data.get("sig")
    payload = data.get("payload")
    if not isinstance(payload, dict) or not isinstance(signature, str):
        print("[CMD] Missing payload/sig")
        return


    if not verify(payload, signature, cfg["shared_secret"]):
        print("[CMD] Signature invalid — command rejected")
        return


    cmd = payload.get("cmd")
    args = payload.get("args", {})
    print(f"[CMD] {cmd} {args}")


    if cmd == "takeoff":
        state.status = "flying"
        state.alt = max(state.alt, float(args.get("alt", 10.0)))
    elif cmd == "land":
        state.status = "landing"
        state.alt = 0.0
        _waypoint = None
    elif cmd == "goto":
        lat = float(args["lat"]) ; lon = float(args["lon"]) ; alt = float(args.get("alt", state.alt))
        _waypoint = (lat, lon)
        state.status = "flying"
        state.alt = alt
    elif cmd == "rth":
        # Return-To-Home : revient au point de départ
        _waypoint = (cfg["start"]["lat"], cfg["start"]["lon"])
        state.status = "flying"
    elif cmd == "ping":
        client.publish(TOPIC_EVENTS, json.dumps({"type": "pong", "ts": time.time()}))
    else:
        print("[CMD] Unknown command")

#def telemetry_loop(client: mqtt.Client):
def telemetry_loop(client):
    global _waypoint, state
    interval = cfg["publish_interval"]
    dyn = cfg["dynamics"]
    while _running:
        if state.status == "flying" and _waypoint is not None:
            #state = move_towards(state, _waypoint[0], _waypoint[1], dt=interval, speed_mps=8.0)
            state = move_towards(
                state,
                _waypoint[0], _waypoint[1],
                dt=interval,
                speed_mps=dyn["cruise_speed_mps"],
                drain_factor=dyn["battery_drain_factor"],
                noise_deg=dyn["heading_noise_deg"],
            )
            # Arrivé au waypoint ?
            if abs(state.lat - _waypoint[0]) < 1e-5 and abs(state.lon - _waypoint[1]) < 1e-5:
                _waypoint = None
                state.status = "idle"
    payload = {
        "drone_id": cfg["drone_id"],
        "ts": time.time(),
        "position": {"lat": state.lat, "lon": state.lon, "alt": state.alt},
        "speed_mps": state.speed_mps,
        "battery_pct": state.battery_pct,
        "status": state.status,
        "heading_deg": state.heading_deg,
    }
    client.publish(TOPIC_TELEMETRY, json.dumps(payload), qos=0)
    time.sleep(interval)




def main():
    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id=cfg["drone_id"])
    if cfg["mqtt"]["username"]:
        client.username_pw_set(cfg["mqtt"]["username"], cfg["mqtt"]["password"])


    client.on_connect = on_connect
    client.on_message = on_message


    client.connect(cfg["mqtt"]["host"], cfg["mqtt"]["port"], keepalive=30)


    t = threading.Thread(target=telemetry_loop, args=(client,), daemon=True)
    t.start()


    try:
        client.loop_forever()
    except KeyboardInterrupt:
        pass
    finally:
        global _running
        _running = False
        print("[SYS] Shutting down")



if __name__ == "__main__":
    main()