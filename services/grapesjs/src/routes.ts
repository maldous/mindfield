import { Express } from "express";
import { Server } from "socket.io";

export default function registerRoutes(app: Express, _io: Server) {
    app.get("/grapesjs/health", (_req, res) => {
        res.status(200).send("GrapesJS service is healthy!");
    });
}
