# SPDX-FileCopyrightText: 2026 Luke Galea
# SPDX-License-Identifier: MIT

defmodule AshSignatures.SignerEvent do
  @moduledoc """
  One thing that happened on a signature request. Append-only: the fragment has no update or
  destroy action, and a host must not add one.

      use MyApp.Resource, fragments: [AshSignatures.SignerEvent]

  `type` is `notified` (it became the signer's turn: the host sends the link), `sent` (the
  host's mailer accepted the link for sending), `delivered` (it reported the link
  delivered), `bounced` (it reported the link could not be delivered), `viewed`,
  `consented`, `signed`, `declined`, `changes_requested`, `reminded` or `withdrawn`.
  `route` is how a person acted: `:in_platform` on the host's surface, or `:upload` for a
  signed copy that arrived as a document version; it is `nil` for events no person caused
  (`notified`, `sent`, `delivered`, `bounced`, `reminded`, `withdrawn`). `signer_id` is `nil` for an uploaded copy,
  which is the request's rather than one signer's.

  `sha256` is, for an in-platform signature, the hash of what the signer was shown
  (`AshSignatures.Digest.shown/1`), and for an upload, the copy's SHA-256.

  `event_hash` is the SHA-256 of the event's canonical JSON, personal fields included, taken
  when it is recorded. The completion record lists every event's hash, so the hash outlives
  the fields once the host seals them. `ip_address`, `user_agent` and `reason`, and on a
  signature what the signer typed (`signed_name`, `signed_title` and `authority`, the
  statement that they may sign), are `sensitive?` and listed in
  `AshSignatures.payload_fields(:signer_event)`. The three typed fields are left out of the
  hashed JSON when they are `nil`, so the hash of an event recorded before they existed is
  unchanged.

  ## The salt

  Every other field the hash covers is kept in plain text, so without a secret in it the
  hash would confirm a guess at the sealed fields once they are gone: an IPv4 address is
  2^32 candidates, and a user agent or a short reason is not many more. An event recorded
  with any personal field therefore gets `salt`, 32 random bytes as lowercase hex, and the
  hash covers it. `salt` is listed in `AshSignatures.payload_fields(:signer_event)`, so the
  host seals it with the fields and erasing them takes it too. An event with none of them
  (the package's own `reminded` and `withdrawn`) has nothing to hide and no salt.
  """

  use Spark.Dsl.Fragment, of: Ash.Resource

  @types [
    :notified,
    :sent,
    :delivered,
    :bounced,
    :viewed,
    :consented,
    :signed,
    :declined,
    :changes_requested,
    :reminded,
    :withdrawn
  ]

  actions do
    defaults [:read]

    create :record do
      accept [
        :request_id,
        :signer_id,
        :type,
        :route,
        :sha256,
        :ip_address,
        :user_agent,
        :reason,
        :signed_name,
        :signed_title,
        :authority
      ]

      # Where the salt goes on a host that seals it, whose `salt` is then no attribute
      # (`AshCloak` swaps it for an encrypted one). Private: never taken as input.
      argument :salt, :string, public?: false, sensitive?: true

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
    attribute :signed_name, :string, public?: true, sensitive?: true
    attribute :signed_title, :string, public?: true, sensitive?: true
    attribute :authority, :string, public?: true, sensitive?: true

    # Written by `AshSignatures.SignerEvent.Changes.Hash`, never accepted as input.
    attribute :salt, :string, public?: true, sensitive?: true
    attribute :event_hash, :string, allow_nil?: false, public?: true
  end
end
