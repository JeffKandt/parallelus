# Node Adapter Stub

The Node adapter skeleton provides script placeholders so repositories can plug
in npm/pnpm tooling later without restructuring `.agents`.

## Scripts
- `.agents/adapters/node/env.sh` – stub that reminds maintainers to implement
  Node bootstrap (nvm, npm install, etc.).
- `.agents/adapters/node/lint.sh` – placeholder; exits with a TODO message.
- `.agents/adapters/node/test.sh` – placeholder; exits with a TODO message.
- `.agents/adapters/node/format.sh` – placeholder; exits with a TODO message.

Add real commands when Node tooling is introduced, then wire the adapter into
`LANG_ADAPTERS` alongside the Python adapter.
