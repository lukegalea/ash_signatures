# SPDX-FileCopyrightText: 2026 Luke Galea
# SPDX-License-Identifier: MIT

defmodule AshSignatures.Test.RecordingProvider do
  @moduledoc """
  A provider that sends each call to the test process, and whose `lookup` answers from the
  process dictionary: a test sets `:recording_lookup` to play a provider that already holds a
  reference from a send whose outcome was not known.
  """

  @behaviour AshSignatures.Provider

  @impl true
  def create(context) do
    send(self(), {:provider, :create, context.request.id})
    {:ok, "recording:" <> to_string(context.request.id)}
  end

  @impl true
  def lookup(context) do
    send(self(), {:provider, :lookup, context.request.id})
    {:ok, Process.get(:recording_lookup)}
  end

  @impl true
  def observe(_ref, _context), do: {:ok, []}

  @impl true
  def fetch(_ref, _context), do: {:ok, []}

  @impl true
  def void(ref, reason, _context) do
    send(self(), {:provider, :void, ref, reason})
    :ok
  end

  @impl true
  def remind(ref, signer, _context) do
    send(self(), {:provider, :remind, ref, signer.id})
    :ok
  end
end
