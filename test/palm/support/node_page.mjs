// Just enough of a browser page for LiteRT's loader to run under Node: it adds
// a <script> element and waits for it to load, and the Emscripten code in that
// script looks for CommonJS helpers when it sees it is running under Node.
// Test support only.
import { createRequire } from 'node:module';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import vm from 'node:vm';

/** Installs the page. [baseUri] is what `document.baseURI` should say. */
export function installPage(baseUri) {
  globalThis.self = globalThis;
  globalThis.require = createRequire(import.meta.url);
  globalThis.document = {
    baseURI: baseUri,
    currentScript: null,
    hidden: false,
    createElement: () => {
      const listeners = {};
      return {
        addEventListener: (event, fn) => (listeners[event] = fn),
        fire: (event, arg) => listeners[event]?.(arg),
      };
    },
    body: {
      appendChild(script) {
        const file = script.src.startsWith('file:') ? fileURLToPath(script.src) : script.src;
        globalThis.document.currentScript = script;
        globalThis.__dirname = path.dirname(file);
        try {
          vm.runInThisContext(readFileSync(file, 'utf8'), { filename: file });
          queueMicrotask(() => script.fire('load'));
        } catch (error) {
          queueMicrotask(() => script.fire('error', error));
        }
      },
    },
  };
}

/** Makes the next relaxed-SIMD feature check fail, so the loader picks the
 *  build meant for browsers without it. */
export function pretendNoRelaxedSimd() {
  const instantiate = WebAssembly.instantiate.bind(WebAssembly);
  let refused = false;
  WebAssembly.instantiate = (source, ...rest) => {
    if (!refused && source instanceof Uint8Array && source.length < 100) {
      refused = true;
      return Promise.reject(new Error('relaxed SIMD is not available (pretended)'));
    }
    return instantiate(source, ...rest);
  };
}
