# SPDX-FileCopyrightText: 2026 Luke Galea
# SPDX-License-Identifier: MIT

defmodule AshSignatures.Test.SealedSignerEvent do
  @moduledoc """
  A host that seals the signer event's personal fields: `AshCloak` turns them into
  arguments, and the host's seal change drops each argument once it is encrypted. In memory,
  since only the recorded hash is under test.
  """

  use Ash.Resource,
    domain: AshSignatures.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshCloak],
    fragments: [AshSignatures.SignerEvent]

  cloak do
    vault(AshSignatures.Test.Vault)
    attributes(AshSignatures.payload_fields(:signer_event))
    decrypt_by_default(AshSignatures.payload_fields(:signer_event))
  end

  changes do
    change {AshSignatures.Test.DropSealedInputs,
            fields: AshSignatures.payload_fields(:signer_event)},
           on: [:create]
  end
end
