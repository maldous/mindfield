import { startExpress } from "@mindfield/logic";
import routes from "./routes.js";

startExpress({
    serviceName: "transform",
    registerRoutes: routes,
    registerQueues: () => {},
});
