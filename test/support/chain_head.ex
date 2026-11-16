# SPDX-FileCopyrightText: 2026 Luke Galea
# SPDX-License-Identifier: MIT

defmodule AshSignatures.Test.ChainHead do
  @moduledoc "A fixed chain head, standing in for the host's audit chain."
  @behaviour AshSignatures.ChainHead

  @impl true
  def head(_tenant), do: "SYNTHETIC-chain-head"
end
