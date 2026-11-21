# SPDX-FileCopyrightText: 2026 Luke Galea
# SPDX-License-Identifier: MIT

defmodule AshSignatures.Test.Request do
  @moduledoc """
  The test host's request: the `AshSignatures.Request` fragment on a plain `Ash.Resource`
  over Postgres, with no tenancy or policies, a recording provider beside the two shipped
  ones, a chain head and a stamp.
  """

  use Ash.Resource,
    domain: AshSignatures.Test.Domain,
    data_layer: AshPostgres.DataLayer,
    fragments: [AshSignatures.Request]

  postgres do
    table "signature_requests"
    repo AshSignatures.Test.Repo
  end

  signature_request do
    request_document(AshSignatures.Test.RequestDocument)
    signer(AshSignatures.Test.Signer)
    signer_event(AshSignatures.Test.SignerEvent)
    completion(AshSignatures.Test.Completion)
    document_version(AshSignatures.Test.DocumentVersion)
    chain_head AshSignatures.Test.ChainHead
    stamp(AshSignatures.Test.Stamp)

    providers in_platform: AshSignatures.Providers.InPlatform,
              upload: AshSignatures.Providers.Upload,
              recording: AshSignatures.Test.RecordingProvider
  end
end
