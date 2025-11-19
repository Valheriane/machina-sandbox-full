# fleet-api/tests/test_health.py
import pytest
from httpx import AsyncClient
from main import app  # FastAPI app

@pytest.mark.asyncio
async def test_health():
    async with AsyncClient(app=app, base_url="http://test") as ac:
        resp = await ac.get("/health")
    assert resp.status_code == 200
    data = resp.json()
    assert data.get("status") == "ok"

@pytest.mark.asyncio
async def test_list_drones_empty_ok():
    async with AsyncClient(app=app, base_url="http://test") as ac:
        resp = await ac.get("/drones")
    assert resp.status_code == 200
    assert isinstance(resp.json(), list)
