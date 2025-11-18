import json, hmac, hashlib


secret = "dev-secret-change-me"


def sign(payload: dict) -> str:
    body = json.dumps(payload, separators=(",", ":"), sort_keys=True).encode()
    return hmac.new(secret.encode(), body, hashlib.sha256).hexdigest()


payload = {"cmd": "goto", "args": {"lat": 43.611, "lon": 3.877, "alt": 20}}
print(sign(payload))