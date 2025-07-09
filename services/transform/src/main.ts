import { startExpress } from '@mindfield/logic';
import routes from './routes';

startExpress({
  serviceName: 'transform',
  registerRoutes: routes,
  registerQueues: () => {},
});
