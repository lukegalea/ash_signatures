# SPDX-FileCopyrightText: 2026 Luke Galea
# SPDX-License-Identifier: MIT

defmodule AshSignatures.Test.Stamp do
  @moduledoc """
  The test host's stamp: on a request about a `"stamped-visit"`, each signature becomes a new
  document version whose bytes name the version it was stamped over, the signer's order and
  what they typed. Every other request is left as it was sent (`:unchanged`), and a typed
  name of `"SYNTHETIC unstampable"` fails, as a host whose stamp cannot write would.
  """

  @behaviour AshSignatures.Stamp

  alias AshSignatures.Test.Domain

  @impl true
  def stamp(%{request: %{subject_type: "stamped-visit"}} = input) do
    case input.signature.signed_name do
      "SYNTHETIC unstampable" ->
        {:error, :no_field}

      name ->
        version =
          Domain.ingest!(
            "consent.pdf",
            "#{input.version_id}+signer#{input.signer.order}:#{name}",
            authorize?: false
          )

        {:ok, %{version_id: version.id, sha256: version.sha256}}
    end
  end

  def stamp(_input), do: :unchanged
end
