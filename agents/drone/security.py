import hmac
import hashlib
import json


# 🛡️ Objectif : vérifier qu'une commande vient d'un émetteur connu
# en calculant une signature HMAC à partir du payload.




def sign(payload: dict, secret: str) -> str:
    body = json.dumps(payload, separators=(",", ":"), sort_keys=True).encode()
    mac = hmac.new(secret.encode(), body, hashlib.sha256).hexdigest()
    return mac




def verify(payload: dict, signature: str, secret: str) -> bool:
    expected = sign(payload, secret)
    return hmac.compare_digest(expected, signature)