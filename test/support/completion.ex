# SPDX-FileCopyrightText: 2026 Luke Galea
# SPDX-License-Identifier: MIT

defmodule AshSignatures.Test.Completion do
  @moduledoc "The test host's resource for the `AshSignatures.Completion` fragment."

  use Ash.Resource,
    domain: AshSignatures.Test.Domain,
    data_layer: AshPostgres.DataLayer,
    fragments: [AshSignatures.Completion]

  postgres do
    table "signature_completions"
    repo AshSignatures.Test.Repo
  end
end
