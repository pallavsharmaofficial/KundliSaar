// Runs a Dart program compiled to JavaScript (web_probe.dart) under Node, in a
// stand-in for a browser page, over the web build's own runtime in web/litert/.
//
//   node run_web_probe.mjs <probe.js> <input directory> [--compat]
//
// The input directory holds frames.json (name, width, height, file for each)
// and the frames' RGBA bytes. Prints the probe's answer as JSON on one line.
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import vm from 'node:vm';

import { installPage, pretendNoRelaxedSimd } from './node_page.mjs';

const [probe, input] = process.argv.slice(2);
const compat = process.argv.includes('--compat');
const root = fileURLToPath(new URL('../../../', import.meta.url));

// The page's base is the site's root, as it is when the app is served from
// /KundliSaar/app/; the probe looks for litert/ under it.
installPage('file://' + path.join(root, 'web') + '/');
if (compat) pretendNoRelaxedSimd();

globalThis.__models = {
  detector: new Uint8Array(readFileSync(path.join(root, 'assets/models/hand_detector.tflite'))),
  landmarker: new Uint8Array(readFileSync(path.join(root, 'assets/models/hand_landmarks_detector.tflite'))),
};
globalThis.__frames = JSON.parse(readFileSync(path.join(input, 'frames.json'), 'utf8')).map((f) => ({
  name: f.name,
  width: f.width,
  height: f.height,
  rgba: new Uint8Array(readFileSync(path.join(input, f.file))),
}));

const answer = new Promise((resolve) => {
  globalThis.__probeDone = resolve;
});
// A page's script may `import()` another module (the probe does, to load the
// runtime's wrapper); a script run by Node's vm needs to be told how.
vm.runInThisContext(readFileSync(probe, 'utf8'), {
  filename: probe,
  importModuleDynamically: vm.constants?.USE_MAIN_CONTEXT_DEFAULT_LOADER ?? ((specifier) => import(specifier)),
});
console.log(await answer);
process.exit(0);
