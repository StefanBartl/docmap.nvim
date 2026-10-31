# Fixture: a project for the rules/plan and rules/validate routes

Fixture project of the `rules/plan` and `rules/validate` routes (`TESTS/rules_api_spec.lua`, `scripts/ci.lua`).
`.env` and `keys/server.pem` hold one harmless word each: they are what the deny list must keep out of a request.
`lua/blob.bin` holds a NUL byte (binary, never sent); `lua/big.lua` is larger than `agent.max_context_bytes`.
