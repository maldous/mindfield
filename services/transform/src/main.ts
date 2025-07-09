import { startExpress } from '@mindfield/logic/bootstrap/express';
import routes from './routes';

startExpress({
  serviceName: 'transform',
  registerRoutes: routes,
  registerQueues: ({ queue }) => {
  },
});
