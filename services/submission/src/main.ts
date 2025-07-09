import { startExpress } from '@mindfield/logic';
import routes from './routes';

startExpress({
  serviceName: 'submission',
  registerRoutes: routes,
  registerQueues: () => {},
});
