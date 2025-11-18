import os


def get_config():
    return {
        "drone_id": os.getenv("DRONE_ID", "drone-001"),
        "mqtt": {
            "host": os.getenv("MQTT_HOST", "localhost"),
            "port": int(os.getenv("MQTT_PORT", 1883)),
            "username": os.getenv("MQTT_USERNAME", ""),
            "password": os.getenv("MQTT_PASSWORD", ""),
            "topic_prefix": os.getenv("TOPIC_PREFIX", "lab"),
        },
        "publish_interval": float(os.getenv("PUBLISH_INTERVAL_SEC", 1.0)),
        "shared_secret": os.getenv("SHARED_SECRET", "dev-secret-change-me"),
        "start": {
            "lat": float(os.getenv("START_LAT", 48.8566)),
            "lon": float(os.getenv("START_LON", 2.3522)),
            "alt": float(os.getenv("START_ALT", 0.0)),
        },
        "dynamics": {
            "cruise_speed_mps": float(os.getenv("CRUISE_SPEED_MPS", 8.0)),     # vitesse
            "battery_drain_factor": float(os.getenv("BATTERY_DRAIN", 0.005)),  # drain
            "heading_noise_deg": float(os.getenv("HEADING_NOISE", 0.0)),       # bruit éventuel
        },
    }