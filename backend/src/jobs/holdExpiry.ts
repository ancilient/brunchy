import { Queue, Worker } from 'bullmq';
import { config } from '../config.js';
import { logger } from '../logger.js';
import { createQueueConnection } from '../redis.js';
import { expireOrder, expireOverdueOrders } from '../services/holds.js';

/**
 * Background work runs outside user requests (build guide: background jobs).
 * Each order gets a delayed job at its hold expiry; a 1-minute sweeper catches anything a job missed
 * (for example if Redis was restarted). Disabled with JOBS_ENABLED=false (the tests call expireOrder directly).
 */
const QUEUE = 'hold-expiry';
let queue: Queue | null = null;
let worker: Worker | null = null;
let sweeper: NodeJS.Timeout | null = null;

export async function scheduleHoldExpiry(orderId: number, expiresAt: Date) {
  if (!config.JOBS_ENABLED) return;
  queue ??= new Queue(QUEUE, { connection: createQueueConnection() });
  const delay = Math.max(0, expiresAt.getTime() - Date.now()) + 1000;
  await queue.add('expire', { orderId }, { jobId: `order-${orderId}`, delay, removeOnComplete: true, removeOnFail: 100 });
}

export function startJobs() {
  if (!config.JOBS_ENABLED) return;
  worker = new Worker(
    QUEUE,
    async (job) => {
      await expireOrder(Number(job.data.orderId));
    },
    { connection: createQueueConnection(), concurrency: 5 },
  );
  worker.on('failed', (job, err) => logger.error({ err, jobId: job?.id }, 'hold-expiry job failed'));
  sweeper = setInterval(() => {
    expireOverdueOrders()
      .then((n) => n && logger.info(`sweeper expired ${n} orders`))
      .catch((err) => logger.error({ err }, 'sweeper failed'));
  }, 60_000);
  logger.info('background jobs started');
}

export async function stopJobs() {
  if (sweeper) clearInterval(sweeper);
  await worker?.close();
  await queue?.close();
  worker = null;
  queue = null;
}
