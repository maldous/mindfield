import { startExpress } from "@mindfield/logic";
import routes from "./routes.js";

startExpress({
    serviceName: "submission",
    registerRoutes: routes,
    registerQueues: () => {},
});
