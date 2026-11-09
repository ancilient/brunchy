import { Router } from 'express';
import { badRequest } from '../errors.js';
import { requireAuth } from '../middleware/auth.js';
import { getMenu, listCanteens } from '../services/menu.js';
import { parseId } from '../util.js';

export const canteensRouter = Router();

canteensRouter.get('/canteens', requireAuth, async (_req, res) => {
  res.json(await listCanteens());
});

/** Supports If-None-Match, so an unchanged menu costs a 304 with no body. */
canteensRouter.get('/canteens/:id/menu', requireAuth, async (req, res) => {
  const id = parseId(req.params.id);
  if (!id) throw badRequest('INVALID_ID', 'Invalid canteen id');
  const { etag, body } = await getMenu(id);
  res.setHeader('ETag', etag);
  res.setHeader('Cache-Control', 'private, max-age=0, must-revalidate');
  if (req.headers['if-none-match'] === etag) {
    res.status(304).end();
    return;
  }
  res.json(body);
});
