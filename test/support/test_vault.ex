# SPDX-FileCopyrightText: 2026 Luke Galea
# SPDX-License-Identifier: MIT

defmodule AshSignatures.Test.Vault do
  @moduledoc "A stand-in vault for the sealed test host: reversible, and plainly not encryption."

  def encrypt!(plaintext), do: "SEALED:" <> Base.encode64(plaintext)
  def decrypt!("SEALED:" <> sealed), do: Base.decode64!(sealed)
end
