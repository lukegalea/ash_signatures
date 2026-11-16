# SPDX-FileCopyrightText: 2026 Luke Galea
# SPDX-License-Identifier: MIT

defmodule AshSignatures.RequestDocument.Changes.CopySourceHash do
  @moduledoc "Copies the source version's SHA-256 onto a request document as it is added."

  use Ash.Resource.Change

  alias AshSignatures.Internal

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      request_resource = AshSignatures.Member.Dsl.request(changeset.resource)
      version_id = Ash.Changeset.get_attribute(changeset, :source_version_id)
      opts = Internal.opts(changeset, context)

      case Internal.version_sha256(request_resource, version_id, opts) do
        {:ok, sha256} ->
          Ash.Changeset.force_change_attribute(changeset, :source_sha256, sha256)

        {:error, message} ->
          Ash.Changeset.add_error(
            changeset,
            Ash.Error.Changes.InvalidAttribute.exception(
              field: :source_version_id,
              message: message
            )
          )
      end
    end)
  end
end
