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

  A signer event's `salt` is not personal data, but it is listed with the event's personal
  fields and must be sealed with them: it is the secret in the event hash
  (`AshSignatures.SignerEvent`), and once it is gone the hash no longer confirms a guess at
  the fields it covered.
  """
  @spec payload_fields(:signer | :signer_event) :: [atom()]
  def payload_fields(:signer), do: [:name, :email]

  def payload_fields(:signer_event),
    do: [:ip_address, :user_agent, :reason, :signed_name, :signed_title, :authority, :salt]

  @doc """
  The signer actions that are the signer's own acts: viewing, agreeing to sign
  electronically, signing, declining and asking for changes.

  Signing is a person's act (rule 4 of the usage rules). A host's policy on these actions
  admits the person the signer row names and nobody else: no system actor, no automation
  principal, no one acting for the person. Naming them here keeps every host's list the
  same as the fragment's.
  """
  @spec person_acts() :: [atom()]
  def person_acts, do: [:view, :consent, :sign, :decline, :request_changes]

  @doc """
  The actions of a fragment that the package calls itself, as the consequence of an act the
  host authorized, with `authorize?: false` (rule 10 of the usage rules).

  A host never needs a grant for them. Its policies can admit them for its own background
  actors only, so that a person holding writes on the resource cannot, for example, move a
  request on (`advance`) or record an event without the act that causes it.

  `expire` and `receive_signed_copy` are not listed: the host calls them, from its own
  trigger and its own upload.
  """
  @spec consequences(:request | :request_document | :signer | :signer_event | :completion) ::
          [atom()]
  def consequences(:request), do: [:advance, :return, :supersede]
  def consequences(:request_document), do: [:record_result, :record_progress]
  def consequences(:signer), do: [:notify, :withdraw]
  def consequences(:signer_event), do: [:record]
  def consequences(:completion), do: [:record]
end
