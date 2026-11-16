# SPDX-FileCopyrightText: 2026 Luke Galea
# SPDX-License-Identifier: MIT

defmodule AshSignatures.Providers.InPlatform do
  @moduledoc """
  Signing on a surface the host renders. Every act is a local write on the signer's own
  row, so there is nothing to observe or fetch: the events and the result versions are
  already rows. Reminders are the `reminded` event; the host's notifier sends the message.
  """

  @behaviour AshSignatures.Provider

  @impl true
  def create(%{request: request}), do: {:ok, "in_platform:" <> to_string(request.id)}

  @impl true
  def lookup(%{request: request}), do: {:ok, request.provider_ref}

  @impl true
  def observe(_ref, _context), do: {:ok, []}

  @impl true
  def fetch(_ref, _context), do: {:ok, []}

  @impl true
  def void(_ref, _reason, _context), do: :ok

  @impl true
  def remind(_ref, _signer, _context), do: :ok
end
