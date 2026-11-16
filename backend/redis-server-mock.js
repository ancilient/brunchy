// redis-server-mock.js
import net from 'node:net';

const store = new Map();

function parseResp(buffer) {
  const str = buffer.toString();
  const lines = str.split('\r\n');
  if (!lines[0].startsWith('*')) {
    return str.trim().split(/\s+/);
  }
  const count = parseInt(lines[0].slice(1), 10);
  const args = [];
  let idx = 1;
  for (let i = 0; i < count; i++) {
    if (lines[idx].startsWith('$')) {
      idx++;
      args.push(lines[idx]);
      idx++;
    }
  }
  return args;
}

const server = net.createServer((socket) => {
  socket.on('error', () => socket.destroy());
  socket.on('data', (data) => {
    try {
      const args = parseResp(data);
      if (!args.length) return;
      const cmd = args[0].toUpperCase();

      if (cmd === 'PING') {
        socket.write('+PONG\r\n');
      } else if (cmd === 'COMMAND' || cmd === 'CLIENT' || cmd === 'SELECT') {
        socket.write('+OK\r\n');
      } else if (cmd === 'INFO') {
        socket.write('$0\r\n\r\n');
      } else if (cmd === 'SET') {
        const key = args[1];
        const val = args[2];
        store.set(key, val);
        socket.write('+OK\r\n');
      } else if (cmd === 'GET') {
        const key = args[1];
        if (store.has(key)) {
          const val = store.get(key);
          const buf = Buffer.from(val);
          socket.write(`$${buf.length}\r\n${val}\r\n`);
        } else {
          socket.write('$-1\r\n');
        }
      } else if (cmd === 'DEL') {
        let count = 0;
        for (let i = 1; i < args.length; i++) {
          if (store.delete(args[i])) count++;
        }
        socket.write(`:${count}\r\n`);
      } else if (cmd === 'INCR') {
        const key = args[1];
        let val = parseInt(store.get(key) || '0', 10);
        val++;
        store.set(key, val.toString());
        socket.write(`:${val}\r\n`);
      } else if (cmd === 'EXPIRE') {
        socket.write(':1\r\n');
      } else if (cmd === 'QUIT') {
        socket.write('+OK\r\n');
        socket.end();
      } else {
        socket.write('+OK\r\n');
      }
    } catch (err) {
      socket.write('-ERR ' + err.message + '\r\n');
    }
  });
});

server.listen(6379, '127.0.0.1', () => {
  console.log('Mock Redis server listening on 127.0.0.1:6379');
});
