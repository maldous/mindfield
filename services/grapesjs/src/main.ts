import { startExpress } from '@mindfield/logic';
import routes from './routes';

startExpress({
  serviceName: 'grapejs',
  registerRoutes: routes,
  registerQueues: () => {},
});
