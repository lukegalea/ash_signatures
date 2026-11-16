# SPDX-FileCopyrightText: 2026 Luke Galea
# SPDX-License-Identifier: MIT

defmodule AshSignatures do
  @moduledoc """
  Signature requests for Ash hosts.

  A **request** asks people to sign or acknowledge exact document versions, in order. Each
  **signer** acts on their own row, every act is an append-only **signer event**, and the
  request ends in one **completion**: a canonical record of what was signed, by whom, over
  which hashes, with its own hash.

  The package ships five Spark fragments, which a host includes on resources built from its
  own base resource:

    * `AshSignatures.Request`
    * `AshSignatures.RequestDocument`
    * `AshSignatures.Signer`
    * `AshSignatures.SignerEvent`
    * `AshSignatures.Completion`

  and the `AshSignatures.Provider` behaviour with two providers that make no network call,
  `AshSignatures.Providers.InPlatform` and `AshSignatures.Providers.Upload`.

  The host supplies the data layer, the relationships between its five resources and to its
  document version resource, tenancy, policies, triggers, notifications, erasure and every
  decision: who may send, the consent wording, how a signer is identified, reminder timing
  and retention. See `documentation/topics/what-the-host-supplies.md`.
  """

  @doc """
  The attributes that hold a signer's personal data, by fragment. A host seals these under
  its erasure scope. Everything else, hashes, roles, order, event types and times, is kept.
  """
  @spec payload_fields(:signer | :signer_event) :: [atom()]
  def payload_fields(:signer), do: [:name, :email]
  def payload_fields(:signer_event), do: [:ip_address, :user_agent, :reason]
end
