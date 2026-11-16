# SPDX-FileCopyrightText: 2026 Luke Galea
# SPDX-License-Identifier: MIT

defmodule AshSignatures.SignerEvent.Changes.Hash do
  @moduledoc "Stamps `occurred_at` and computes `event_hash` as an event is recorded."

  use Ash.Resource.Change

  @fields [:request_id, :signer_id, :type, :route, :sha256, :ip_address, :user_agent, :reason]

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      occurred_at = DateTime.utc_now()
      changeset = Ash.Changeset.force_change_attribute(changeset, :occurred_at, occurred_at)

      Ash.Changeset.force_change_attribute(
        changeset,
        :event_hash,
        AshSignatures.SignerEvent.Changes.Hash.hash(changeset)
      )
    end)
  end

  @doc """
  The event hash of a changeset or a recorded event: SHA-256 over the canonical JSON of
  `occurred_at` and every field the event was recorded with.
  """
  @spec hash(Ash.Changeset.t() | Ash.Resource.record()) :: String.t()
  def hash(%Ash.Changeset{} = changeset),
    do:
      [:occurred_at | @fields]
      |> Map.new(&{&1, Ash.Changeset.get_attribute(changeset, &1)})
      |> digest()

  def hash(event), do: event |> Map.take([:occurred_at | @fields]) |> digest()

  defp digest(map), do: AshSignatures.Digest.sha256_hex(map)
end
