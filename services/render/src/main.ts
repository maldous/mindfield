import { startExpress } from '@mindfield/logic/bootstrap/express';
import routes from './routes';

startExpress({
  serviceName: 'render',
  registerRoutes: routes,
  registerQueues: ({ queue }) => {
  },
});
