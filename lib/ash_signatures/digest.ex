# SPDX-FileCopyrightText: 2026 Luke Galea
# SPDX-License-Identifier: MIT

defmodule AshSignatures.Digest do
  @moduledoc """
  Canonical JSON (RFC 8785) and SHA-256 over it, for the documents digest, event hashes and
  the completion record. Atoms become strings and datetimes ISO 8601, so a hash does not
  depend on key order or on Elixir types.
  """

  @max_safe_integer 9_007_199_254_740_991

  @doc "The JSON form of `term` that the digests are taken over."
  @spec canonical(term()) :: term()
  def canonical(nil), do: nil
  def canonical(boolean) when is_boolean(boolean), do: boolean
  def canonical(string) when is_binary(string), do: string

  def canonical(integer) when is_integer(integer) and abs(integer) <= @max_safe_integer,
    do: integer

  def canonical(integer) when is_integer(integer), do: Integer.to_string(integer)
  def canonical(atom) when is_atom(atom), do: Atom.to_string(atom)
  def canonical(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)
  def canonical(list) when is_list(list), do: Enum.map(list, &canonical/1)

  def canonical(%{__struct__: struct}) do
    raise ArgumentError, "cannot digest a #{inspect(struct)}; pass its JSON form instead"
  end

  def canonical(map) when is_map(map),
    do: Map.new(map, fn {key, value} -> {key_string(key), canonical(value)} end)

  @doc "The RFC 8785 canonical JSON bytes of `term`."
  @spec jcs(term()) :: binary()
  def jcs(term), do: term |> canonical() |> Jcs.encode()

  @doc "SHA-256 of the canonical JSON of `term`, as lowercase hex."
  @spec sha256_hex(term()) :: String.t()
  def sha256_hex(term), do: :crypto.hash(:sha256, jcs(term)) |> Base.encode16(case: :lower)

  @doc """
  One hash for the versions a signer is shown: the version's own SHA-256 when there is one
  document, otherwise the SHA-256 of the canonical JSON list of them, in position order.
  """
  @spec shown([String.t()]) :: String.t()
  def shown([sha256]), do: sha256
  def shown(sha256s) when is_list(sha256s), do: sha256_hex(sha256s)

  defp key_string(key) when is_binary(key), do: key
  defp key_string(key) when is_atom(key), do: Atom.to_string(key)
end
