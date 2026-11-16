# SPDX-FileCopyrightText: 2026 Luke Galea
# SPDX-License-Identifier: MIT

defmodule AshSignatures.Request.Verifiers.VerifyHost do
  @moduledoc """
  Checks that every provider named in `signature_request` implements
  `AshSignatures.Provider`. The sibling resources are checked when they are first used,
  because they may compile after the request resource.
  """

  use Spark.Dsl.Verifier

  @callbacks AshSignatures.Provider.behaviour_info(:callbacks)

  @impl true
  def verify(dsl) do
    module = Spark.Dsl.Verifier.get_persisted(dsl, :module)
    providers = Spark.Dsl.Verifier.get_option(dsl, [:signature_request], :providers)

    case Enum.reject(providers, fn {_key, provider} -> provider?(provider) end) do
      [] ->
        :ok

      bad ->
        {:error,
         Spark.Error.DslError.exception(
           module: module,
           path: [:signature_request, :providers],
           message:
             "these providers do not implement AshSignatures.Provider: #{inspect(Keyword.keys(bad))}"
         )}
    end
  end

  defp provider?(module) do
    Code.ensure_loaded?(module) and
      Enum.all?(@callbacks, fn {name, arity} -> function_exported?(module, name, arity) end)
  end
end
