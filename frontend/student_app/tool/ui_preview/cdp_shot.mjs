// Capture a screenshot of a CDP page target
const wsUrl = process.argv[2];
const outFile = process.argv[3];
const width = parseInt(process.argv[4] || '414', 10);
const height = parseInt(process.argv[5] || '896', 10);
const scale = parseFloat(process.argv[6] || '2');

const ws = new WebSocket(wsUrl);
let id = 0;
const pending = new Map();

function send(method, params = {}) {
  return new Promise((resolve, reject) => {
    const msgId = ++id;
    pending.set(msgId, { resolve, reject });
    ws.send(JSON.stringify({ id: msgId, method, params }));
  });
}

ws.onmessage = (ev) => {
  const msg = JSON.parse(ev.data);
  if (msg.id && pending.has(msg.id)) {
    const { resolve, reject } = pending.get(msg.id);
    pending.delete(msg.id);
    if (msg.error) reject(new Error(JSON.stringify(msg.error)));
    else resolve(msg.result);
  }
};

ws.onopen = async () => {
  try {
    await send('Emulation.setDeviceMetricsOverride', { width, height, deviceScaleFactor: scale, mobile: true });
    await new Promise(r => setTimeout(r, 800));
    const shot = await send('Page.captureScreenshot', { format: 'png' });
    const fs = await import('node:fs');
    fs.writeFileSync(outFile, Buffer.from(shot.data, 'base64'));
    console.log('saved', outFile);
    ws.close();
    process.exit(0);
  } catch (e) { console.error('ERR', e.message); process.exit(1); }
};

ws.onerror = (e) => { console.error('WSERR', e.message || 'error'); process.exit(1); };
setTimeout(() => { console.error('TIMEOUT'); process.exit(1); }, 15000);
