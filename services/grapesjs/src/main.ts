import { startExpress } from '@mindfield/logic/bootstrap/express';
import routes from './routes';

startExpress({
  serviceName: 'grapejs',
  registerRoutes: routes,
  registerQueues: ({ queue }) => {
  },
});
