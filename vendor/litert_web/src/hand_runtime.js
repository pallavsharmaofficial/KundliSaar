// A small, synchronous face on LiteRT.js for the hand models.
//
// KundliSaar's hand pipeline (lib/palm/) is written against a model that is
// called like a function: floats in, floats out, no waiting. LiteRT.js's public
// run() is asynchronous because it also drives WebGPU. On the CPU build of the
// runtime the work underneath is synchronous, so this file reaches the compiled
// model directly and returns the answer at once. Nothing here touches the
// network: the runtime's .js and .wasm are fetched from the directory the page
// names, which is this site's own.
import { Tensor, loadAndCompile, loadLiteRt, supportsFeature } from '@litertjs/core';

let loading = null;

/**
 * LiteRT.js asks the browser for a WebGPU device while it loads, whether it
 * will use it or not. These models run on the CPU kernels so that the numbers
 * match the phone's, so the GPU is hidden for the moment it takes to load.
 */
function hideWebGpu() {
  const nav = globalThis.navigator;
  if (!nav || !('gpu' in nav)) return () => {};
  try {
    Object.defineProperty(nav, 'gpu', { value: undefined, configurable: true });
  } catch (_) {
    return () => {};
  }
  return () => {
    try {
      delete nav.gpu;
    } catch (_) {
      /* leave it hidden */
    }
  };
}

/**
 * Loads the WebAssembly runtime from [directory] (a URL ending in a slash).
 * Resolves with which build was chosen: "standard", or "compat" for browsers
 * without relaxed SIMD. Safe to call again; it loads once.
 */
export function loadRuntime(directory) {
  if (!loading) {
    loading = (async () => {
      const restore = hideWebGpu();
      try {
        await loadLiteRt(directory);
      } finally {
        restore();
      }
      return (await supportsFeature('relaxedSimd')) ? 'standard' : 'compat';
    })().catch((error) => {
      loading = null;
      throw error;
    });
  }
  return loading;
}

/**
 * Compiles a .tflite model, given as bytes, for the CPU. The returned object
 * is the whole of what the Dart side sees.
 */
export async function loadModel(bytes) {
  const compiled = await loadAndCompile(bytes, { accelerator: 'wasm' });
  const input = compiled.getInputDetails()[0];
  const inputShape = Array.from(input.shape);
  const outputs = compiled.getOutputDetails();
  const outputNames = outputs.map((o) => o.name);
  const outputShapes = outputs.map((o) => Array.from(o.shape));
  const inner = compiled.liteRtCompiledModel;
  let closed = false;

  return {
    inputShape,
    outputNames,
    outputShapes,
    /** Runs the network on [data] (a Float32Array) and returns every output. */
    run(data) {
      if (closed) throw new Error('The model has been closed.');
      const tensor = new Tensor(data, inputShape);
      let buffers;
      try {
        buffers = inner.run(0, [tensor.liteRtTensorBuffer]);
      } finally {
        tensor.delete();
      }
      if (!buffers || typeof buffers.then === 'function') {
        throw new Error('This LiteRT build runs models asynchronously.');
      }
      return buffers.map((buffer) => {
        const out = new Tensor(buffer);
        try {
          return out.toTypedArray();
        } finally {
          out.delete();
        }
      });
    },
    close() {
      if (closed) return;
      closed = true;
      compiled.delete();
    },
  };
}
