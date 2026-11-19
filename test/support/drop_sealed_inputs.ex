# SPDX-FileCopyrightText: 2026 Luke Galea
# SPDX-License-Identifier: MIT

defmodule AshSignatures.Test.DropSealedInputs do
  @moduledoc """
  What a host's own seal change does once it has encrypted a field: it drops the argument,
  so no later hook sees the plaintext.
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, opts, _context) do
    Enum.reduce(opts[:fields], changeset, fn field, changeset ->
      case Ash.Changeset.fetch_argument(changeset, field) do
        {:ok, value} ->
          changeset
          |> AshCloak.encrypt_and_set(field, value)
          |> Ash.Changeset.delete_argument(field)

        :error ->
          changeset
      end
    end)
  end
end
