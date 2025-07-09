import { startExpress } from '@mindfield/logic/bootstrap/express';
import routes from './routes';

startExpress({
  serviceName: 'submission',
  registerRoutes: routes,
  registerQueues: ({ queue }) => {
  },
});
