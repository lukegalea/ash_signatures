# SPDX-FileCopyrightText: 2026 Luke Galea
# SPDX-License-Identifier: MIT

defmodule AshSignatures.Providers.Upload do
  @moduledoc """
  Signing on paper. A person downloads the document, it is signed outside the platform, and
  the signed copy is uploaded and handed to `receive_signed_copy`. Nothing is sent and
  nothing can be observed; the upload is the only event.
  """

  @behaviour AshSignatures.Provider

  @impl true
  def create(%{request: request}), do: {:ok, "upload:" <> to_string(request.id)}

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
