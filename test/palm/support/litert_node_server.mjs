// Runs the web build's own hand-model runtime (web/litert/) under Node and
// answers over a TCP socket, so a Dart test can drive the very JavaScript and
// WebAssembly the browser would load, and compare it with TensorFlow Lite on
// the same inputs. Test support only; nothing in the app uses it.
//
//   node litert_node_server.mjs [--compat]
//
// Prints "PORT <n>" once it is listening. One client at a time. Messages are
// a little-endian u32 length followed by that many bytes.
//   request  : u8 op, then
//              1 load  : utf8 path of a .tflite file
//              2 run   : u32 model id, float32 input
//              3 info  : (nothing)
//   response : u8 status (0 ok, 1 error), then
//              load    : JSON {id, inputShape, outputNames, outputShapes}
//              run     : u32 count, then for each output u32 length, floats
//              info    : JSON {variant}
//              error   : utf8 message
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import net from 'node:net';

import { installPage, pretendNoRelaxedSimd } from './node_page.mjs';

const compat = process.argv.includes('--compat');
const litertDir = fileURLToPath(new URL('../../../web/litert/', import.meta.url));

installPage('file://' + litertDir);
if (compat) pretendNoRelaxedSimd();

const runtime = await import(new URL('litert_hand.js', 'file://' + litertDir));
const variant = await runtime.loadRuntime('file://' + litertDir);
if (compat && variant !== 'compat') throw new Error(`wanted the compat build, got ${variant}`);
// (Without --compat, the build is whichever this version of Node's engine picks.)

const models = [];

function ok(...parts) {
  const body = Buffer.concat([Buffer.from([0]), ...parts]);
  const head = Buffer.alloc(4);
  head.writeUInt32LE(body.length);
  return Buffer.concat([head, body]);
}

function fail(error) {
  const body = Buffer.concat([Buffer.from([1]), Buffer.from(String(error?.stack ?? error))]);
  const head = Buffer.alloc(4);
  head.writeUInt32LE(body.length);
  return Buffer.concat([head, body]);
}

async function handle(body) {
  const op = body[0];
  if (op === 1) {
    const file = body.subarray(1).toString('utf8');
    const model = await runtime.loadModel(new Uint8Array(readFileSync(file)));
    models.push(model);
    return ok(
      Buffer.from(
        JSON.stringify({
          id: models.length - 1,
          inputShape: model.inputShape,
          outputNames: model.outputNames,
          outputShapes: model.outputShapes,
        }),
      ),
    );
  }
  if (op === 2) {
    const id = body.readUInt32LE(1);
    const floats = body.subarray(5);
    const input = new Float32Array(floats.buffer.slice(floats.byteOffset, floats.byteOffset + floats.length));
    const outputs = models[id].run(input);
    const parts = [];
    const count = Buffer.alloc(4);
    count.writeUInt32LE(outputs.length);
    parts.push(count);
    for (const out of outputs) {
      const len = Buffer.alloc(4);
      len.writeUInt32LE(out.length);
      parts.push(len, Buffer.from(out.buffer, out.byteOffset, out.byteLength));
    }
    return ok(...parts);
  }
  if (op === 3) return ok(Buffer.from(JSON.stringify({ variant })));
  throw new Error(`unknown op ${op}`);
}

const server = net.createServer((socket) => {
  let pending = Buffer.alloc(0);
  let busy = Promise.resolve();
  socket.on('data', (chunk) => {
    pending = Buffer.concat([pending, chunk]);
    while (pending.length >= 4 && pending.length >= 4 + pending.readUInt32LE(0)) {
      const length = pending.readUInt32LE(0);
      const body = pending.subarray(4, 4 + length);
      pending = pending.subarray(4 + length);
      busy = busy.then(async () => {
        try {
          socket.write(await handle(body));
        } catch (error) {
          socket.write(fail(error));
        }
      });
    }
  });
  socket.on('close', () => {
    for (const model of models.splice(0)) model.close();
    server.close();
    process.exit(0);
  });
});
server.listen(0, '127.0.0.1', () => {
  console.log(`PORT ${server.address().port}`);
});
