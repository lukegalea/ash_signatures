# SPDX-FileCopyrightText: 2026 Luke Galea
# SPDX-License-Identifier: MIT

defmodule AshSignatures.DigestTest do
  use ExUnit.Case, async: true

  alias AshSignatures.Digest

  test "the hash does not depend on key order or on atoms versus strings" do
    assert Digest.sha256_hex(%{b: 1, a: :x}) == Digest.sha256_hex(%{"a" => "x", "b" => 1})
  end

  test "one document is shown as its own hash; several as the hash of the list, in order" do
    assert Digest.shown(["abc"]) == "abc"
    refute Digest.shown(["a", "b"]) == Digest.shown(["b", "a"])
  end

  test "a struct must be turned into its JSON form first" do
    assert_raise ArgumentError, fn -> Digest.canonical(%URI{}) end
  end
end
