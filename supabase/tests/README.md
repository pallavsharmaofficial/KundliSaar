# Funnel backend tests

Run from the repository root (Node 22.6 or newer):

```sh
# Validation and CORS rules shared by the edge functions
node --experimental-strip-types --test supabase/tests/lead_test.mjs

# The migration's tables, RLS and RPCs, in PGlite (Postgres in WASM) with a
# stand-in for Supabase's auth schema. PGlite is installed outside the repo:
mkdir -p /tmp/pglite && (cd /tmp/pglite && npm i @electric-sql/pglite)
PGLITE_DIR=/tmp/pglite node supabase/tests/rls_test.mjs
```
