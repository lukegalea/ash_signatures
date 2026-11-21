# SPDX-FileCopyrightText: 2026 Luke Galea
# SPDX-License-Identifier: MIT

defmodule AshSignatures.Provider do
  @moduledoc """
  How a request reaches whoever runs the signing.

  The behaviour is asynchronous even for providers that answer at once: `create` returns a
  reference, state is observed, and an outcome that is not known is reconciled by `lookup`
  before anything is sent again. A hosted provider needs exactly this shape, so adding one
  later changes no caller.

  `send` calls `lookup` first and reuses the reference it returns; only when there is none
  does it call `create`. `void` is called when a sent request ends without completing, and
  `remind` when a signer is reminded.

  `notifies_signers?/0` is optional, and true when a provider leaves it out: whether it tells
  each signer when it is their turn. One that tells no one (paper) returns false, and `send`
  records no `notified` event for it.

  `observe` and `fetch` have no caller in this package yet. They are the calls a hosted
  provider's reconciliation makes after a webhook nudge.
  """

  @typedoc "What every callback is given: the request, the actor and the tenant."
  @type context :: %{request: Ash.Resource.record(), actor: term(), tenant: term()}

  @typedoc "The provider's reference for a request."
  @type ref :: String.t()

  @typedoc "Something the provider says happened to a signer."
  @type observation :: %{signer_id: term(), type: atom(), occurred_at: DateTime.t()}

  @callback create(context()) :: {:ok, ref()} | {:error, term()}
  @callback lookup(context()) :: {:ok, ref() | nil} | {:error, term()}
  @callback observe(ref(), context()) :: {:ok, [observation()]} | {:error, term()}
  @callback fetch(ref(), context()) ::
              {:ok, [%{document_id: term(), version_id: term()}]} | {:error, term()}
  @callback void(ref(), reason :: atom(), context()) :: :ok | {:error, term()}
  @callback remind(ref(), signer :: Ash.Resource.record(), context()) :: :ok | {:error, term()}
  @callback notifies_signers?() :: boolean()

  @optional_callbacks notifies_signers?: 0
end
