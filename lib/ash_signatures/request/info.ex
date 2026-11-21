# SPDX-FileCopyrightText: 2026 Luke Galea
# SPDX-License-Identifier: MIT

defmodule AshSignatures.Request.Info do
  @moduledoc "Reads what a host supplied in its `signature_request` section."

  @doc "The host's request document resource."
  @spec request_document(Ash.Resource.t()) :: Ash.Resource.t()
  def request_document(resource), do: opt(resource, :request_document)

  @doc "The host's signer resource."
  @spec signer(Ash.Resource.t()) :: Ash.Resource.t()
  def signer(resource), do: opt(resource, :signer)

  @doc "The host's signer event resource."
  @spec signer_event(Ash.Resource.t()) :: Ash.Resource.t()
  def signer_event(resource), do: opt(resource, :signer_event)

  @doc "The host's completion resource."
  @spec completion(Ash.Resource.t()) :: Ash.Resource.t()
  def completion(resource), do: opt(resource, :completion)

  @doc "The host's document version resource."
  @spec document_version(Ash.Resource.t()) :: Ash.Resource.t()
  def document_version(resource), do: opt(resource, :document_version)

  @doc "The providers a request may be sent through, by key."
  @spec providers(Ash.Resource.t()) :: keyword(module())
  def providers(resource), do: opt(resource, :providers)

  @doc "The provider module for `key`, or `nil` when there is none."
  @spec provider(Ash.Resource.t(), atom() | nil) :: module() | nil
  def provider(_resource, nil), do: nil
  def provider(resource, key), do: Keyword.get(providers(resource), key)

  @doc "The host's `AshSignatures.ChainHead`, or `nil`."
  @spec chain_head(Ash.Resource.t()) :: module() | nil
  def chain_head(resource), do: opt(resource, :chain_head)

  @doc "The host's `AshSignatures.Stamp`, or `nil`."
  @spec stamp(Ash.Resource.t()) :: module() | nil
  def stamp(resource), do: opt(resource, :stamp)

  defp opt(resource, name), do: Spark.Dsl.Extension.get_opt(resource, [:signature_request], name)
end
