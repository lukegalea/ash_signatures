# SPDX-FileCopyrightText: 2026 Luke Galea
# SPDX-License-Identifier: MIT

defmodule AshSignatures.Test.Signer do
  @moduledoc "The test host's resource for the `AshSignatures.Signer` fragment."

  use Ash.Resource,
    domain: AshSignatures.Test.Domain,
    data_layer: AshPostgres.DataLayer,
    fragments: [AshSignatures.Signer]

  postgres do
    table "signature_signers"
    repo AshSignatures.Test.Repo
  end

  signatures do
    request(AshSignatures.Test.Request)
  end
end
