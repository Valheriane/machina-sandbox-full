"""
Manager de flotte : conserve les workers (threads) en mémoire,
et publie des commandes signées si on le souhaite (via l'API).
"""
import os
import json, time
from typing import Dict
import paho.mqtt.client as mqtt
from security import sign
from sim import DroneWorker
from config import get_config

class FleetManager:
    def __init__(self):
        cfg = get_config()
        self.cfg = cfg
        self.workers: Dict[str, DroneWorker] = {}
        
        # --- NOUVEAU : flag pour désactiver MQTT en tests ---
        if os.getenv("DISABLE_MQTT", "").lower() in {"1", "true", "yes"}:
            print("[FleetManager] MQTT disabled via DISABLE_MQTT env var")
            return  # on ne crée pas de client MQTT

        # client MQTT côté API (pour publier des commandes au besoin)
        self.client = mqtt.Client()  # paho 1.x
        self.client.connect(cfg["mqtt"]["host"], cfg["mqtt"]["port"], keepalive=15)
        self.client.loop_start()

    def ensure_worker(self, drone) -> DroneWorker:
        if drone.id in self.workers and self.workers[drone.id].is_running():
            return self.workers[drone.id]
        w = DroneWorker(
            drone_id=drone.id,
            topic_prefix=drone.topic_prefix,
            mqtt_host=self.cfg["mqtt"]["host"],
            mqtt_port=self.cfg["mqtt"]["port"],
            shared_secret=self.cfg["shared_secret"],
            start_lat=drone.start_lat,
            start_lon=drone.start_lon,
            start_alt=drone.start_alt,
            publish_interval_sec=drone.publish_interval_sec,
            cruise_speed_mps=drone.cruise_speed_mps,
            battery_drain=drone.battery_drain,
            heading_noise=drone.heading_noise,
        )
        self.workers[drone.id] = w
        return w

    def start(self, drone):
        w = self.ensure_worker(drone)
        w.start()

    def stop(self, drone_id: str):
        w = self.workers.get(drone_id)
        if w:
            w.stop()

    def publish_cmd(self, topic_prefix: str, drone_id: str, payload: dict):
        """
        Publie une commande signée sur le topic MQTT du drone.
        Utilisé par l'endpoint POST /drones/{id}/cmd pour que le front n'ait pas à signer.
        """
        sig = sign(payload, self.cfg["shared_secret"])
        envelope = {"sig": sig, "payload": payload}
        topic = f"{topic_prefix}/drone/{drone_id}/commands"
        self.client.publish(topic, json.dumps(envelope), qos=0)
        return topic, envelope
