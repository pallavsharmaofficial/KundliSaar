#!/bin/sh
# Rebuilds web/litert/ from the pinned @litertjs/core (Apache 2.0).
#
#   litert_hand.js                      src/hand_runtime.js bundled with
#                                       LiteRT.js's loader, one ES module
#   litert_wasm_internal.{js,wasm}      the CPU runtime, for browsers with
#                                       relaxed SIMD
#   litert_wasm_compat_internal.{js,wasm}  the same for browsers without it
#
# The threaded and JSPI builds are left out on purpose: threads need
# cross-origin isolation headers that GitHub Pages cannot set, and the hand
# pipeline wants a synchronous run() that JSPI would take away.
#
# Needs Node and the network once; the output is committed, so nobody needs to
# run this to build the app.
set -e
cd "$(dirname "$0")"
OUT=../../web/litert
npm ci --ignore-scripts
mkdir -p "$OUT"
npx esbuild src/hand_runtime.js --bundle --format=esm --minify --legal-comments=none \
  --banner:js='/* KundliSaar: LiteRT.js 2.5.3 (Apache-2.0, Google LLC) bundled with a small synchronous wrapper. Licence: LICENSE-Apache-2.0.txt, credits: assets/data/ATTRIBUTION.md. */' \
  --outfile="$OUT/litert_hand.js"
for f in litert_wasm_internal.js litert_wasm_internal.wasm \
         litert_wasm_compat_internal.js litert_wasm_compat_internal.wasm; do
  cp "node_modules/@litertjs/core/wasm/$f" "$OUT/$f"
done
cp ../../assets/models/LICENSE-Apache-2.0.txt "$OUT/LICENSE-Apache-2.0.txt"
( cd "$OUT" && shasum -a 256 litert_hand.js litert_wasm_*.js litert_wasm_*.wasm )
