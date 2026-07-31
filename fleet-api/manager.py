import json
import os
import time
from typing import Dict

import paho.mqtt.client as mqtt

from config import get_config
from security import sign
from sim import DroneWorker


class FleetManager:
    def __init__(self):
        self.cfg = get_config()
        self.workers: Dict[str, DroneWorker] = {}
        self.client: mqtt.Client | None = None

        self.mqtt_disabled = (
            os.getenv("DISABLE_MQTT", "").lower()
            in {"1", "true", "yes"}
        )

        if self.mqtt_disabled:
            print(
                "[FleetManager] MQTT disabled via DISABLE_MQTT env var",
                flush=True,
            )
            return

        self._start_mqtt_client()

    def _start_mqtt_client(self) -> None:
        host = self.cfg["mqtt"]["host"]
        port = self.cfg["mqtt"]["port"]

        self.client = mqtt.Client()

        # Reconnexion progressive : 1 s, 2 s, 4 s... jusqu'à 30 s.
        self.client.reconnect_delay_set(
            min_delay=1,
            max_delay=30,
        )

        # Non bloquant : le broker peut ne pas être prêt immédiatement.
        self.client.connect_async(
            host,
            port,
            keepalive=15,
        )

        # Lance la boucle réseau dans un thread en arrière-plan.
        self.client.loop_start()

        print(
            f"[FleetManager] MQTT connection started "
            f"for {host}:{port}",
            flush=True,
        )

    def mqtt_connected(self) -> bool:
        return bool(
            self.client is not None
            and self.client.is_connected()
        )

    def wait_for_mqtt(self, timeout: float = 5.0) -> bool:
        if self.client is None:
            return False

        deadline = time.monotonic() + timeout

        while time.monotonic() < deadline:
            if self.client.is_connected():
                return True

            time.sleep(0.1)

        return self.client.is_connected()

    def ensure_worker(self, drone) -> DroneWorker:
        if (
            drone.id in self.workers
            and self.workers[drone.id].is_running()
        ):
            return self.workers[drone.id]

        worker = DroneWorker(
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

        self.workers[drone.id] = worker
        return worker

    def start(self, drone) -> None:
        worker = self.ensure_worker(drone)
        worker.start()

    def stop(self, drone_id: str) -> None:
        worker = self.workers.get(drone_id)

        if worker:
            worker.stop()

    def publish_cmd(
        self,
        topic_prefix: str,
        drone_id: str,
        payload: dict,
    ):
        if not self.wait_for_mqtt(timeout=5.0):
            raise RuntimeError(
                "MQTT temporarily unavailable"
            )

        if self.client is None:
            raise RuntimeError(
                "MQTT client not initialized"
            )

        signature = sign(
            payload,
            self.cfg["shared_secret"],
        )

        envelope = {
            "sig": signature,
            "payload": payload,
        }

        topic = (
            f"{topic_prefix}/drone/"
            f"{drone_id}/commands"
        )

        result = self.client.publish(
            topic,
            json.dumps(envelope),
            qos=0,
        )

        if result.rc != mqtt.MQTT_ERR_SUCCESS:
            raise RuntimeError(
                f"MQTT publish failed with code {result.rc}"
            )

        return topic, envelope

    def close(self) -> None:
        if self.client is None:
            return

        try:
            self.client.disconnect()
        finally:
            self.client.loop_stop()
