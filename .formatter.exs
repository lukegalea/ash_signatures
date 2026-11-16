# SPDX-FileCopyrightText: 2026 Luke Galea
# SPDX-License-Identifier: MIT

# The `signature_request` section's options, here and for a host that imports this
# package's formatter rules (`import_deps: [:ash_signatures]`).
locals_without_parens = [providers: 1, chain_head: 1]

[
  locals_without_parens: locals_without_parens,
  export: [locals_without_parens: locals_without_parens],
  import_deps: [:ash, :ash_postgres, :ash_state_machine],
  plugins: [Spark.Formatter],
  inputs: [
    "{mix,.formatter}.exs",
    "{config,lib,test,scripts}/**/*.{ex,exs}"
  ]
]
