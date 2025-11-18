# HMAC signature pour sécuriser les commandes (même logique que l'agent).
import hmac, hashlib, json

def sign(payload: dict, secret: str) -> str:
    body = json.dumps(payload, separators=(",", ":"), sort_keys=True).encode()
    return hmac.new(secret.encode(), body, hashlib.sha256).hexdigest()

def verify(payload: dict, signature: str, secret: str) -> bool:
    expected = sign(payload, secret)
    return hmac.compare_digest(expected, signature)
