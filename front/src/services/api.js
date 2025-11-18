import axios from "axios";

const API = axios.create({
  baseURL: import.meta.env.VITE_API_URL || "http://localhost:8000",
  timeout: 10000,
});

export const createDrone = (data) => API.post("/drones", data).then(r => r.data);
export const listDrones  = () => API.get("/drones").then(r => r.data);
export const startDrone  = (id) => API.post(`/drones/${id}/start`).then(r => r.data);
export const stopDrone   = (id) => API.post(`/drones/${id}/stop`).then(r => r.data);
export const sendCmd     = (id, cmd, args) =>
  API.post(`/drones/${id}/cmd`, { cmd, args }).then(r => r.data);

export const deleteDrone = (id) => API.delete(`/drones/${id}`).then(r => r.data);

export const updateDrone = (id, data) => API.patch(`/drones/${id}`, data).then(r => r.data);

