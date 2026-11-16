# SPDX-FileCopyrightText: 2026 Luke Galea
# SPDX-License-Identifier: MIT

defmodule AshSignatures.Test.DocumentVersion do
  @moduledoc """
  The test host's document version: immutable bytes' SHA-256 and a filename. A host would use
  its own content-addressed store; this is the least that satisfies `document_version`.
  """

  use Ash.Resource,
    domain: AshSignatures.Test.Domain,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "document_versions"
    repo AshSignatures.Test.Repo
  end

  actions do
    defaults [:read]

    create :ingest do
      accept [:filename]
      argument :bytes, :string, allow_nil?: false

      change fn changeset, _context ->
        bytes = Ash.Changeset.get_argument(changeset, :bytes)
        sha256 = :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
        Ash.Changeset.force_change_attribute(changeset, :sha256, sha256)
      end
    end
  end

  attributes do
    uuid_v7_primary_key :id
    attribute :filename, :string, allow_nil?: false, public?: true
    attribute :sha256, :string, allow_nil?: false, public?: true
  end
end
