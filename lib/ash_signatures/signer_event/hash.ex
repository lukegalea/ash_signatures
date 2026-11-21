# SPDX-FileCopyrightText: 2026 Luke Galea
# SPDX-License-Identifier: MIT

defmodule AshSignatures.SignerEvent.Changes.Hash do
  @moduledoc """
  Stamps `occurred_at`, writes the salt and computes `event_hash` as an event is recorded.

  The personal fields (`AshSignatures.payload_fields(:signer_event)`) are read when this
  change runs, as an argument or an attribute. A host that seals them may turn them into
  arguments (`AshCloak` does) and drop those arguments once they are encrypted, before any
  `before_action` hook runs. Reading them here, ahead of the host's own changes, keeps them
  in the hash either way.

  When any of them is present, the event gets a fresh salt (32 random bytes, lowercase hex)
  and the hash covers it, so the hash cannot confirm a guess at the fields once the host
  has erased them with the salt. On a host that seals the salt it goes into the action's
  private `salt` argument, where the host's seal change finds it like the other fields;
  otherwise it is the `salt` attribute.
  """

  use Ash.Resource.Change

  @fields [:request_id, :signer_id, :type, :route, :sha256, :ip_address, :user_agent, :reason]
  # What a signer types when signing. Hashed only when present, so an event recorded before
  # these fields existed keeps its hash.
  @typed [:signed_name, :signed_title, :authority]
  @personal AshSignatures.payload_fields(:signer_event) -- [:salt]

  @impl true
  def change(changeset, _opts, _context) do
    payload = Map.new(@personal, &{&1, input(changeset, &1)})
    salt = salt(payload)
    changeset = put_salt(changeset, salt)

    Ash.Changeset.before_action(changeset, fn changeset ->
      occurred_at = DateTime.utc_now()

      fields =
        (@fields -- @personal)
        |> Map.new(&{&1, Ash.Changeset.get_attribute(changeset, &1)})
        |> Map.merge(payload)
        |> Map.put(:occurred_at, occurred_at)
        |> drop_absent_typed()
        |> with_salt(salt)

      changeset
      |> Ash.Changeset.force_change_attribute(:occurred_at, occurred_at)
      |> Ash.Changeset.force_change_attribute(:event_hash, digest(fields))
    end)
  end

  # Nothing personal, nothing to guess: no salt, and the hash is taken as it always was.
  defp salt(payload) do
    if Enum.any?(payload, fn {_field, value} -> not is_nil(value) end),
      do: :crypto.strong_rand_bytes(32) |> Base.encode16(case: :lower)
  end

  defp put_salt(changeset, nil), do: changeset

  defp put_salt(changeset, salt) do
    if Ash.Resource.Info.attribute(changeset.resource, :salt),
      do: Ash.Changeset.force_change_attribute(changeset, :salt, salt),
      else: Ash.Changeset.set_private_argument(changeset, :salt, salt)
  end

  defp with_salt(fields, nil), do: fields
  defp with_salt(fields, salt), do: Map.put(fields, :salt, salt)

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
  The event hash of a recorded event: SHA-256 over the canonical JSON of `occurred_at`,
  every field the event was recorded with and, when it has one, its salt.

  A host that seals the personal fields must load them and the salt (decrypted) before
  calling this. Once their scope is shredded the hash can no longer be recomputed, and no
  guess at them can be checked against it; the completion record keeps the hash itself.
  """
  @spec hash(Ash.Resource.record()) :: String.t()
  def hash(event) do
    event
    |> Map.take([:occurred_at | @fields ++ @typed])
    |> drop_absent_typed()
    |> with_salt(Map.get(event, :salt))
    |> digest()
  end

  defp drop_absent_typed(fields),
    do: Map.reject(fields, fn {key, value} -> key in @typed and is_nil(value) end)

  defp digest(map), do: AshSignatures.Digest.sha256_hex(map)
end
