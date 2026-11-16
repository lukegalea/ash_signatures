# SPDX-FileCopyrightText: 2026 Luke Galea
# SPDX-License-Identifier: MIT

defmodule AshSignatures.Completion do
  @moduledoc """
  The one record a completed signature request ends in.

      use MyApp.Resource, fragments: [AshSignatures.Completion]

  `record` is the canonical JSON form built by `AshSignatures.Request.Complete.record/3`: the
  request, its documents' source and signed hashes, its signers by reference, every event's
  hash in order, the completion time and the host's chain head. `record_hash` is the SHA-256
  of its RFC 8785 canonical JSON; `intact?/1` checks it. Nothing in the record is personal
  data, so it survives erasure whole.
  """

  use Spark.Dsl.Fragment, of: Ash.Resource

  actions do
    defaults [:read]

    create :record do
      accept [:request_id, :record]
      change AshSignatures.Completion.Changes.Hash
    end
  end

  attributes do
    uuid_v7_primary_key :id
    attribute :request_id, :uuid, allow_nil?: false, public?: true
    attribute :record, :map, allow_nil?: false, public?: true
    attribute :record_hash, :string, allow_nil?: false, public?: true
    attribute :chain_head, :string, public?: true
    attribute :completed_at, :utc_datetime_usec, allow_nil?: false, public?: true
  end

  identities do
    identity :unique_request, [:request_id]
  end

  @doc "Whether `completion.record_hash` is the hash of its record."
  @spec intact?(Ash.Resource.record()) :: boolean()
  def intact?(completion),
    do: AshSignatures.Digest.sha256_hex(completion.record) == completion.record_hash
end
