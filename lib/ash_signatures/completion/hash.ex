# SPDX-FileCopyrightText: 2026 Luke Galea
# SPDX-License-Identifier: MIT

defmodule AshSignatures.Completion.Changes.Hash do
  @moduledoc "Sets `record_hash`, `chain_head` and `completed_at` from the completion record."

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    record = Ash.Changeset.get_attribute(changeset, :record) || %{}

    completed_at =
      case DateTime.from_iso8601(to_string(record["completed_at"])) do
        {:ok, datetime, _offset} -> datetime
        _ -> DateTime.utc_now()
      end

    changeset
    |> Ash.Changeset.force_change_attribute(:record_hash, AshSignatures.Digest.sha256_hex(record))
    |> Ash.Changeset.force_change_attribute(:chain_head, record["chain_head"])
    |> Ash.Changeset.force_change_attribute(:completed_at, completed_at)
  end
end
