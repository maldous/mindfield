import { Express } from "express";
import { Server } from "socket.io";

export default function registerRoutes(app: Express, _io: Server) {
    app.get("/render/health", (_req, res) => {
        res.status(200).send("Render service is healthy!");
    });
}
