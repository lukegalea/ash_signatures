# SPDX-FileCopyrightText: 2026 Luke Galea
# SPDX-License-Identifier: MIT

defmodule AshSignatures.SignerEvent do
  @moduledoc """
  One thing that happened on a signature request. Append-only: the fragment has no update or
  destroy action, and a host must not add one.

      use MyApp.Resource, fragments: [AshSignatures.SignerEvent]

  `type` is `viewed`, `consented`, `signed`, `declined`, `changes_requested`, `reminded` or
  `withdrawn`. `route` is how a person acted: `:in_platform` on the host's surface, or
  `:upload` for a signed copy that arrived as a document version; it is `nil` for the
  package's own events (`reminded`, `withdrawn`). `signer_id` is `nil` for an uploaded copy,
  which is the request's rather than one signer's.

  `sha256` is, for an in-platform signature, the hash of what the signer was shown
  (`AshSignatures.Digest.shown/1`), and for an upload, the copy's SHA-256.

  `event_hash` is the SHA-256 of the event's canonical JSON, personal fields included, taken
  when it is recorded. The completion record lists every event's hash, so the hash outlives
  the fields once the host seals them. `ip_address`, `user_agent` and `reason` are
  `sensitive?` and listed in `AshSignatures.payload_fields(:signer_event)`.
  """

  use Spark.Dsl.Fragment, of: Ash.Resource

  @types [:viewed, :consented, :signed, :declined, :changes_requested, :reminded, :withdrawn]

  actions do
    defaults [:read]

    create :record do
      accept [:request_id, :signer_id, :type, :route, :sha256, :ip_address, :user_agent, :reason]
      change AshSignatures.SignerEvent.Changes.Hash
    end
  end

  attributes do
    uuid_v7_primary_key :id
    attribute :request_id, :uuid, allow_nil?: false, public?: true
    attribute :signer_id, :uuid, public?: true

    attribute :type, :atom do
      allow_nil? false
      public? true
      constraints one_of: @types
    end

    attribute :route, :atom, public?: true, constraints: [one_of: [:in_platform, :upload]]
    attribute :occurred_at, :utc_datetime_usec, allow_nil?: false, public?: true
    attribute :sha256, :string, public?: true
    attribute :ip_address, :string, public?: true, sensitive?: true
    attribute :user_agent, :string, public?: true, sensitive?: true
    attribute :reason, :string, public?: true, sensitive?: true
    attribute :event_hash, :string, allow_nil?: false, public?: true
  end
end
