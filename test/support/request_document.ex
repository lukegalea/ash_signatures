# SPDX-FileCopyrightText: 2026 Luke Galea
# SPDX-License-Identifier: MIT

defmodule AshSignatures.Test.RequestDocument do
  @moduledoc "The test host's resource for the `AshSignatures.RequestDocument` fragment."

  use Ash.Resource,
    domain: AshSignatures.Test.Domain,
    data_layer: AshPostgres.DataLayer,
    fragments: [AshSignatures.RequestDocument]

  postgres do
    table "signature_request_documents"
    repo AshSignatures.Test.Repo
  end

  signatures do
    request(AshSignatures.Test.Request)
  end
end
