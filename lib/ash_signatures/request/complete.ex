# SPDX-FileCopyrightText: 2026 Luke Galea
# SPDX-License-Identifier: MIT

defmodule AshSignatures.Request.Complete do
  @moduledoc """
  What follows a request completing: signers who have not acted are withdrawn, the
  completion record is written, and every other open request on the same subject is
  superseded.

  When a signed copy completed the request (`signed_copy:` its SHA-256), the signers who had
  not acted are not withdrawn: the copy carries their signatures, so each is `signed` on it
  (`sign_on_copy`), with a `signed` event of route `:upload` and the copy's hash.

  The record names the request, its documents' source and signed hashes, its signers by
  reference (never their personal data), the hash of every event in order, the time and the
  host's chain head. `AshSignatures.Completion` hashes it.
  """

  require Ash.Query

  alias AshSignatures.{Digest, Internal}
  alias AshSignatures.Request.Info

  @doc false
  def run(resource, request, opts, how \\ []) do
    case how[:signed_copy] do
      nil -> Internal.withdraw_open_signers(resource, request.id, opts)
      sha256 -> Internal.sign_open_signers_on_copy(resource, request.id, sha256, opts)
    end

    resource
    |> Info.completion()
    |> Ash.Changeset.for_create(
      :record,
      %{request_id: request.id, record: record(resource, request, opts)},
      opts
    )
    |> Ash.create!()

    supersede_others(resource, request, opts)
  end

  @doc "The canonical completion record for `request`."
  @spec record(Ash.Resource.t(), Ash.Resource.record(), keyword()) :: map()
  def record(resource, request, opts) do
    chain_head =
      case Info.chain_head(resource) do
        nil -> nil
        module -> module.head(opts[:tenant])
      end

    Digest.canonical(%{
      request: %{
        id: request.id,
        subject_type: request.subject_type,
        subject_id: request.subject_id,
        purpose: request.purpose,
        routing: request.routing,
        provider: request.provider,
        provider_ref: request.provider_ref,
        documents_digest: request.documents_digest,
        sent_at: request.sent_at
      },
      documents:
        for document <- Internal.documents(resource, request.id, opts) do
          %{
            id: document.id,
            position: document.position,
            source_version_id: document.source_version_id,
            source_sha256: document.source_sha256,
            result_version_id: document.result_version_id,
            result_sha256: document.result_sha256
          }
        end,
      signers:
        for signer <- Internal.signers(resource, request.id, opts) do
          %{
            id: signer.id,
            role: signer.role,
            order: signer.order,
            status: signer.status,
            signed_at: signer.signed_at,
            shown_sha256: signer.shown_sha256
          }
        end,
      events:
        for event <- Internal.events(resource, request.id, opts) do
          %{id: event.id, type: event.type, event_hash: event.event_hash}
        end,
      completed_at: request.ended_at,
      chain_head: chain_head
    })
  end

  defp supersede_others(resource, request, opts) do
    resource
    |> Ash.Query.for_read(:read, %{}, opts)
    |> Ash.Query.filter(
      subject_type == ^request.subject_type and subject_id == ^request.subject_id and
        id != ^request.id and status in [:draft, :sent, :partially_signed]
    )
    |> Ash.read!()
    |> Enum.each(&(&1 |> Ash.Changeset.for_update(:supersede, %{}, opts) |> Ash.update!()))
  end
end
