# SPDX-FileCopyrightText: 2026 Luke Galea
# SPDX-License-Identifier: MIT

defmodule AshSignatures.SignerEvent.Changes.Hash do
  @moduledoc """
  Stamps `occurred_at` and computes `event_hash` as an event is recorded.

  The personal fields (`AshSignatures.payload_fields(:signer_event)`) are read when this
  change runs, as an argument or an attribute. A host that seals them may turn them into
  arguments (`AshCloak` does) and drop those arguments once they are encrypted, before any
  `before_action` hook runs. Reading them here, ahead of the host's own changes, keeps them
  in the hash either way.
  """

  use Ash.Resource.Change

  @fields [:request_id, :signer_id, :type, :route, :sha256, :ip_address, :user_agent, :reason]
  @payload AshSignatures.payload_fields(:signer_event)

  @impl true
  def change(changeset, _opts, _context) do
    payload = Map.new(@payload, &{&1, input(changeset, &1)})

    Ash.Changeset.before_action(changeset, fn changeset ->
      occurred_at = DateTime.utc_now()

      fields =
        (@fields -- @payload)
        |> Map.new(&{&1, Ash.Changeset.get_attribute(changeset, &1)})
        |> Map.merge(payload)
        |> Map.put(:occurred_at, occurred_at)

      changeset
      |> Ash.Changeset.force_change_attribute(:occurred_at, occurred_at)
      |> Ash.Changeset.force_change_attribute(:event_hash, digest(fields))
    end)
  end

  # An argument when the host has turned the field into one; otherwise the attribute. A
  # sealed field left out of the inputs is neither, and is absent (`nil`) like an unsealed one.
  defp input(changeset, field) do
    case Ash.Changeset.fetch_argument(changeset, field) do
      {:ok, value} ->
        value

      :error ->
        if Ash.Resource.Info.attribute(changeset.resource, field),
          do: Ash.Changeset.get_attribute(changeset, field)
    end
  end

  @doc """
  The event hash of a recorded event: SHA-256 over the canonical JSON of `occurred_at` and
  every field the event was recorded with.

  A host that seals the personal fields must load them (decrypted) before calling this.
  Once their scope is shredded the hash can no longer be recomputed; the completion record
  keeps the hash itself.
  """
  @spec hash(Ash.Resource.record()) :: String.t()
  def hash(event), do: event |> Map.take([:occurred_at | @fields]) |> digest()

  defp digest(map), do: AshSignatures.Digest.sha256_hex(map)
end
