# SPDX-FileCopyrightText: 2026 Luke Galea
# SPDX-License-Identifier: MIT

defmodule AshSignatures.Signer do
  @moduledoc """
  One person asked to sign or acknowledge a request, in `order`.

      use MyApp.Resource, fragments: [AshSignatures.Signer]

      signatures do
        request MyClinic.Consent.Request
      end

  `role` is the host's key for the part the signer plays (`:patient`, `:clinician`). How a
  signer is identified (an account, an email link) is the host's: add its own attributes
  beside these, and its own policies.

  `name` and `email` are personal data: they are `sensitive?` and listed in
  `AshSignatures.payload_fields(:signer)`, for the host to seal under its erasure scope.

  ## States

  `pending` until it is the signer's turn, then `notified`, `viewed`, and one of `signed`,
  `declined` or `changes_requested`. A signer who had not acted when the request ended is
  `withdrawn`, unless a signed copy completed it: a copy carries every signature the request
  asked for, so a signer who had not signed is `signed` on it (`sign_on_copy`). Because only
  the current signer is ever `notified` or `viewed`, the status is also what keeps signers in
  order.

  ## Actions

  Each act records one `AshSignatures.SignerEvent` with the time and, when given, the IP
  address and user agent.

    * `add` (create): `request_id`, `role`, `order`, `name`, `email`, on a draft request only.
    * `view`: the signer opened the documents.
    * `consent`: the signer agreed to sign electronically. Needs `viewed`. The consent
      wording is the host's.
    * `sign`: needs `viewed` and consent. Takes what the signer typed, all optional here
      (a host requires what it needs): `signed_name`, `signed_title` and `authority`, the
      statement that they may sign; they go on the `signed` event, sealed with its other
      personal fields. Records the SHA-256 of what the signer was shown
      (`AshSignatures.Digest.shown/1` over each document as it stands: the source, or its
      last stamped version), stamps the signature into the documents when the host supplies
      an `AshSignatures.Stamp`, and moves the request on: the next signer is notified, or the
      request completes.
    * `decline`, `request_changes`: need a `reason`. The request is `returned`.
    * `remind`: records `reminded` and calls the provider's `remind`. No state change.
    * `record_delivery`: records `delivered`, when the host's mailer reports the signer's
      link delivered. No state change; only while it is the signer's turn.
    * `notify`, `withdraw`, `sign_on_copy`: the package's own writes. `notify` records
      `notified`. `sign_on_copy` records the signer's `signed` event, route `:upload`, with the
      SHA-256 of the signed copy that completed the request.

  The host's policies decide who may take each act. Signing is a person's act: a host must
  not let an automation principal reach `sign`.
  """

  use Spark.Dsl.Fragment,
    of: Ash.Resource,
    extensions: [AshStateMachine, AshSignatures.Member.Dsl]

  state_machine do
    state_attribute :status
    initial_states [:pending]
    default_initial_state :pending

    transitions do
      transition :notify, from: :pending, to: :notified
      transition :view, from: [:notified, :viewed], to: :viewed
      transition :sign, from: :viewed, to: :signed
      transition :decline, from: [:notified, :viewed], to: :declined
      transition :request_changes, from: [:notified, :viewed], to: :changes_requested
      transition :withdraw, from: [:pending, :notified, :viewed], to: :withdrawn
      transition :sign_on_copy, from: [:pending, :notified, :viewed], to: :signed
    end
  end

  actions do
    defaults [:read]

    create :add do
      accept [:request_id, :role, :order, :name, :email]
      validate AshSignatures.Validations.RequestIsDraft
    end

    update :notify do
      require_atomic? false
      change {AshSignatures.Signer.Changes.Act, type: :notified}
    end

    update :view do
      require_atomic? false
      argument :ip_address, :string, sensitive?: true
      argument :user_agent, :string, sensitive?: true
      change {AshSignatures.Signer.Changes.Act, type: :viewed}
    end

    update :consent do
      require_atomic? false
      argument :ip_address, :string, sensitive?: true
      argument :user_agent, :string, sensitive?: true
      change {AshSignatures.Signer.Changes.Act, type: :consented}
    end

    update :sign do
      require_atomic? false
      argument :ip_address, :string, sensitive?: true
      argument :user_agent, :string, sensitive?: true
      argument :signed_name, :string, sensitive?: true, constraints: [min_length: 1]
      argument :signed_title, :string, sensitive?: true, constraints: [min_length: 1]
      argument :authority, :string, sensitive?: true, constraints: [min_length: 1]
      change {AshSignatures.Signer.Changes.Act, type: :signed}
    end

    update :decline do
      require_atomic? false
      argument :reason, :string, allow_nil?: false, sensitive?: true, constraints: [min_length: 1]
      argument :ip_address, :string, sensitive?: true
      argument :user_agent, :string, sensitive?: true
      change {AshSignatures.Signer.Changes.Act, type: :declined}
    end

    update :request_changes do
      require_atomic? false
      argument :reason, :string, allow_nil?: false, sensitive?: true, constraints: [min_length: 1]
      argument :ip_address, :string, sensitive?: true
      argument :user_agent, :string, sensitive?: true
      change {AshSignatures.Signer.Changes.Act, type: :changes_requested}
    end

    update :remind do
      require_atomic? false
      change {AshSignatures.Signer.Changes.Act, type: :reminded}
    end

    update :record_delivery do
      require_atomic? false
      change {AshSignatures.Signer.Changes.Act, type: :delivered}
    end

    update :withdraw do
      require_atomic? false
      change {AshSignatures.Signer.Changes.Act, type: :withdrawn}
    end

    update :sign_on_copy do
      require_atomic? false
      argument :sha256, :string, allow_nil?: false, constraints: [min_length: 64, max_length: 64]
      change {AshSignatures.Signer.Changes.Act, type: :signed_on_copy}
    end
  end

  attributes do
    uuid_v7_primary_key :id
    attribute :request_id, :uuid, allow_nil?: false, public?: true
    attribute :role, :atom, allow_nil?: false, public?: true

    attribute :order, :integer do
      allow_nil? false
      public? true
      constraints min: 1
    end

    attribute :name, :string, public?: true, sensitive?: true
    attribute :email, :string, public?: true, sensitive?: true
    attribute :shown_sha256, :string, public?: true
    attribute :notified_at, :utc_datetime_usec, public?: true
    attribute :viewed_at, :utc_datetime_usec, public?: true
    attribute :consented_at, :utc_datetime_usec, public?: true
    attribute :signed_at, :utc_datetime_usec, public?: true
    attribute :ended_at, :utc_datetime_usec, public?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_order, [:request_id, :order]
  end
end
