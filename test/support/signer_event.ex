# SPDX-FileCopyrightText: 2026 Luke Galea
# SPDX-License-Identifier: MIT

defmodule AshSignatures.Test.SignerEvent do
  @moduledoc "The test host's resource for the `AshSignatures.SignerEvent` fragment."

  use Ash.Resource,
    domain: AshSignatures.Test.Domain,
    data_layer: AshPostgres.DataLayer,
    fragments: [AshSignatures.SignerEvent]

  postgres do
    table "signature_signer_events"
    repo AshSignatures.Test.Repo
  end
end
