import os
os.environ["DISABLE_MQTT"] = "1"   # pour éviter la connexion au broker pendant les tests

import pytest
from httpx import AsyncClient, ASGITransport
from main import app  # FastAPI app


@pytest.mark.asyncio
async def test_health():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        resp = await ac.get("/health")
    assert resp.status_code == 200
    data = resp.json()
    assert data.get("status") == "ok"


@pytest.mark.asyncio
async def test_list_drones_empty_ok():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        resp = await ac.get("/drones")
    assert resp.status_code == 200
    assert isinstance(resp.json(), list)
