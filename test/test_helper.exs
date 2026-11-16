# SPDX-FileCopyrightText: 2026 Luke Galea
# SPDX-License-Identifier: MIT

# Create the test host's database if it is missing, start the repo, and run the
# generated migrations in priv/repo/migrations.
AshSignatures.Test.Repo.__adapter__().storage_up(AshSignatures.Test.Repo.config())

{:ok, _} = AshSignatures.Test.Repo.start_link()

Ecto.Migrator.run(AshSignatures.Test.Repo, Path.expand("priv/repo/migrations"), :up, all: true)

Ecto.Adapters.SQL.Sandbox.mode(AshSignatures.Test.Repo, :manual)

ExUnit.start()
