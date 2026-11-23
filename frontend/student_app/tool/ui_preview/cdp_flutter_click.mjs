// Dispatch pointer events on the flutter-view then screenshot
const wsUrl = process.argv[2];
const outFile = process.argv[3];
const x = parseInt(process.argv[4], 10);
const y = parseInt(process.argv[5], 10);
const width = parseInt(process.argv[6] || '414', 10);
const height = parseInt(process.argv[7] || '896', 10);

const ws = new WebSocket(wsUrl);
let id = 0; const p = new Map();
const send = (m, pr = {}) => new Promise((res, rej) => { const i = ++id; p.set(i, { res, rej }); ws.send(JSON.stringify({ id: i, method: m, params: pr })); });
ws.onmessage = e => { const m = JSON.parse(e.data); if (m.id && p.has(m.id)) { const { res, rej } = p.get(m.id); p.delete(m.id); m.error ? rej(new Error(JSON.stringify(m.error))) : res(m.result); } };

ws.onopen = async () => {
  try {
    await send('Emulation.setDeviceMetricsOverride', { width, height, deviceScaleFactor: 2, mobile: true });
    await new Promise(r => setTimeout(r, 400));
    const setup = `(() => {
      window.__cv = document.querySelector('flutter-view')
        || document.querySelector('flt-glass-pane')
        || document.querySelector('canvas')
        || document.body;
      window.__pt = (type, buttons) => {
        const x = ${x}, y = ${y};
        const view = window.__cv;
        view.dispatchEvent(new PointerEvent('pointer' + type, {
          bubbles: true, cancelable: true, composed: true,
          clientX: x, clientY: y, screenX: x, screenY: y,
          pointerId: 7, pointerType: 'mouse', isPrimary: true,
          button: 0, buttons: type === 'down' ? 1 : 0, detail: 1, view: window,
        }));
        if (type === 'down' || type === 'up') {
          view.dispatchEvent(new MouseEvent((type === 'down' ? 'mouse' : 'mouse') + type, {
            bubbles: true, cancelable: true, composed: true,
            clientX: x, clientY: y, screenX: x, screenY: y,
            button: 0, buttons: type === 'down' ? 1 : 0, detail: 1, view: window,
          }));
        }
        return view.tagName;
      };
      return window.__cv.tagName;
    })()`;
    const setupR = await send('Runtime.evaluate', { expression: setup, returnByValue: true });
    console.log('view:', setupR.result.value);
    const wait = (ms) => new Promise(res => setTimeout(res, ms));
    for (const type of ['over', 'move', 'down']) {
      await send('Runtime.evaluate', { expression: `window.__pt('${type}')`, returnByValue: true });
      await wait(90);
    }
    await wait(120);
    for (const type of ['up']) {
      await send('Runtime.evaluate', { expression: `window.__pt('${type}')`, returnByValue: true });
      await wait(90);
    }
    await send('Runtime.evaluate', { expression: `(() => { const x=${x}, y=${y}; window.__cv.dispatchEvent(new MouseEvent('click', {bubbles:true,cancelable:true,composed:true,clientX:x,clientY:y,button:0,buttons:0,detail:1,view:window})); return 1; })()`, returnByValue: true });
    console.log('clicked', x, y);
    await wait(1300);
    const s = await send('Page.captureScreenshot', { format: 'png' });
    const fs = await import('node:fs');
    fs.writeFileSync(outFile, Buffer.from(s.data, 'base64'));
    console.log('saved', outFile);
    process.exit(0);
  } catch (e) { console.error('ERR', e.message); process.exit(1); }
};
ws.onerror = () => { console.error('WSERR'); process.exit(1); };
setTimeout(() => { console.error('TIMEOUT'); process.exit(1); }, 15000);
