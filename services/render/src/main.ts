import { startExpress } from '@mindfield/logic';
import routes from './routes';

startExpress({
  serviceName: 'render',
  registerRoutes: routes,
  registerQueues: () => {},
});
