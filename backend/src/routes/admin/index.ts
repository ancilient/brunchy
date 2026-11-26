import { Router } from 'express';
import { requireAuth } from '../../middleware/auth.js';
import { loadPanel } from '../../services/access.js';
import { catalogRouter } from './catalog.js';
import { miscRouter } from './misc.js';
import { moneyRouter } from './money.js';
import { reportsRouter } from './reports.js';
import { ordersRouter } from './orders.js';
import { peopleRouter } from './people.js';

/**
 * The admin panel API (admin_web). Every /admin route needs a panel account (admin or manager); each route then
 * checks the account's section permission (GET = view, writes = edit) and, for managers, their canteen.
 * Contract: docs/admin-dashboard (Brunchy Admin Backend Handover, section 6).
 */
export const adminRouter = Router();
adminRouter.use('/admin', requireAuth, loadPanel);
adminRouter.use(catalogRouter, peopleRouter, ordersRouter, miscRouter, moneyRouter, reportsRouter);
