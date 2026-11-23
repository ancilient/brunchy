const wsUri0 = process.argv[2];
const wsUri = (wsUri0 || 'ws://127.0.0.1:50342/oxhewuSP1hw=/ws');
const ws = new WebSocket(wsUri);
let id = 0; const p = new Map();
const send = (m, pr = {}) => new Promise((res, rej) => { const i = ++id; p.set(i, { res, rej }); ws.send(JSON.stringify({ id: i, method: m, params: pr })); });
ws.onmessage = e => { const m = JSON.parse(e.data); if (m.id && p.has(m.id)) { const { res, rej } = p.get(m.id); p.delete(m.id); m.error ? rej(new Error(JSON.stringify(m.error))) : res(m.result); } };
ws.onopen = async () => {
  try {
    const vm = await send('getVM');
    const iso = vm.isolates.find(i => i.name === 'main') || vm.isolates[0];
    const r = await send('reloadSources', { isolateId: iso.id, force: true, pause: false });
    console.log('reload result:', JSON.stringify(r).substring(0, 300));
    process.exit(0);
  } catch (e) { console.error('ERR', e.message); process.exit(1); }
};
ws.onerror = () => { console.error('WSERR'); process.exit(1); };
setTimeout(() => { console.error('TIMEOUT'); process.exit(1); }, 20000);
