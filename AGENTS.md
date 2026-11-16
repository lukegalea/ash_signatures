<!--
SPDX-FileCopyrightText: 2026 Luke Galea
SPDX-License-Identifier: MIT
-->

# AGENTS.md

This is `ash_signatures`, signature requests for Ash Framework hosts, packaged as a dependency.

## Agent constitution

This repository follows `AGENT_PRINCIPLES.md` v1.5, the agent constitution of the ai-sdlc platform:
<https://github.com/lukegalea/ai-sdlc/blob/master/AGENT_PRINCIPLES.md>. That file is the root policy for every agent
session here. This file adds the rules of this repository only. If a rule here contradicts a security rule there, stop
and ask a human. If you cannot open the link, these rules from it still apply:

- Do not approve your own work. A human approves every merge and every release.
- Do not put a secret in a file, a commit, a log, or a prompt.
- Do not publish anything outside this repository without human approval.
- Do not say that work is verified unless a CI result shows it.

## Project guidelines

- The package ships declarations: Spark fragments, a behaviour and two providers that make no network call. The host
  supplies the base resource, data layer, tenancy, policies, triggers, notifications, audit and erasure. Never add any
  of those to a fragment.
- Nothing here may refer to Phoenix or to a particular application. `scripts/check-boundary.sh` fails CI on a
  reference to a `Phoenix*`, `AshEnterprise*` or `AshBpmn*` module, or on a Phoenix package in the dependency tree.
- No mix tasks.
- Examples in code, tests and documentation use a generic clinic scenario, with synthetic data marked `SYNTHETIC`.
- The test host in `test/support` is plain `Ash.Resource` on Postgres. Generate its migrations with
  `MIX_ENV=test mix ash.codegen <name>`; do not write migrations by hand.
- Run everything inside devenv: `devenv up -d` starts the test database, `devenv shell -- <command>` runs a command.

## Before you finish

CI runs `mix format --check-formatted`, `mix credo --strict`, `mix compile --force --warnings-as-errors` (test and
dev), `mix test` against Postgres 16, `mix ash.codegen --check`, `mix dialyzer`, `mix docs`,
`mix deps.unlock --check-unused`, `mix deps.audit`, `mix hex.audit`, the boundary check and its self-test, and REUSE.
