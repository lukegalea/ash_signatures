# SPDX-FileCopyrightText: 2026 Luke Galea
# SPDX-License-Identifier: MIT

defmodule AshSignatures.ChainHead do
  @moduledoc """
  The head of the host's audit chain for a tenant, written into each completion record so
  the record points at the chain it was written beside. Optional: a host that names no
  module in `signature_request` gets `nil` in the record.
  """

  @callback head(tenant :: term()) :: String.t() | nil
end
