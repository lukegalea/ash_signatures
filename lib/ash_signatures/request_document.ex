# SPDX-FileCopyrightText: 2026 Luke Galea
# SPDX-License-Identifier: MIT

defmodule AshSignatures.RequestDocument do
  @moduledoc """
  One document of a signature request: the exact version signers are shown, its position, and
  the signed result's version once one arrives.

      use MyApp.Resource, fragments: [AshSignatures.RequestDocument]

      signatures do
        request MyClinic.Consent.Request
      end

  `source_sha256` is copied from the version when the document is added, so the request's
  digest and completion record never depend on reading the version again. `result_version_id`
  and `result_sha256` are set by `AshSignatures.Request`'s `receive_signed_copy`.

  ## Actions

    * `add` (create): `request_id`, `source_version_id` and `position`, on a draft request
      only (`AshSignatures.Validations.RequestIsDraft`).
    * `record_result` (update): the package's own write of a signed copy.
  """

  use Spark.Dsl.Fragment, of: Ash.Resource, extensions: [AshSignatures.Member.Dsl]

  actions do
    defaults [:read]

    create :add do
      accept [:request_id, :source_version_id, :position]
      validate AshSignatures.Validations.RequestIsDraft
      change AshSignatures.RequestDocument.Changes.CopySourceHash
    end

    update :record_result do
      accept [:result_version_id, :result_sha256]
    end
  end

  attributes do
    uuid_v7_primary_key :id
    attribute :request_id, :uuid, allow_nil?: false, public?: true

    attribute :position, :integer do
      allow_nil? false
      public? true
      constraints min: 1
    end

    attribute :source_version_id, :uuid, allow_nil?: false, public?: true
    attribute :source_sha256, :string, allow_nil?: false, public?: true
    attribute :result_version_id, :uuid, public?: true
    attribute :result_sha256, :string, public?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_position, [:request_id, :position]
  end
end
