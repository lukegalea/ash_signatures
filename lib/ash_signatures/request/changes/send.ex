# SPDX-FileCopyrightText: 2026 Luke Galea
# SPDX-License-Identifier: MIT

defmodule AshSignatures.Request.Changes.Send do
  @moduledoc """
  Sends a draft request: checks its documents and signers, fixes `documents_digest`, gets the
  provider's reference (`lookup` first, `create` only when there is none) and notifies the
  first signer.
  """

  use Ash.Resource.Change

  alias AshSignatures.{Digest, Internal}
  alias AshSignatures.Request.Info

  @impl true
  def change(changeset, _opts, context) do
    key = Ash.Changeset.get_argument(changeset, :provider)

    case Info.provider(changeset.resource, key) do
      nil ->
        Ash.Changeset.add_error(
          changeset,
          Ash.Error.Changes.InvalidArgument.exception(
            field: :provider,
            message: "is not one of this request's providers (%{keys})",
            vars: [keys: changeset.resource |> Info.providers() |> Keyword.keys() |> inspect()]
          )
        )

      provider ->
        changeset
        |> AshStateMachine.transition_state(:sent)
        |> Ash.Changeset.before_action(&prepare(&1, key, provider, context))
        |> Ash.Changeset.after_action(&notify_first(&1, &2, context))
    end
  end

  defp prepare(changeset, key, provider, context) do
    opts = Internal.opts(changeset, context)
    request = changeset.data
    documents = Internal.documents(changeset.resource, request.id, opts)
    signers = Internal.signers(changeset.resource, request.id, opts)

    cond do
      documents == [] ->
        invalid(changeset, "a request needs at least one document before it is sent")

      signers == [] ->
        invalid(changeset, "a request needs at least one signer before it is sent")

      Enum.map(signers, & &1.order) != Enum.to_list(1..length(signers)) ->
        invalid(changeset, "signers must be numbered 1, 2, 3 … in order, with no gaps")

      true ->
        digest =
          Digest.sha256_hex(%{
            documents: Enum.map(documents, & &1.source_sha256),
            signers: Enum.map(signers, &%{role: &1.role, order: &1.order})
          })

        context = Internal.provider_context(%{request | provider: key}, opts)

        case reference(provider, context) do
          {:ok, ref} ->
            changeset
            |> Ash.Changeset.force_change_attribute(:provider, key)
            |> Ash.Changeset.force_change_attribute(:provider_ref, ref)
            |> Ash.Changeset.force_change_attribute(:documents_digest, digest)
            |> Ash.Changeset.force_change_attribute(:sent_at, Internal.now())

          {:error, reason} ->
            invalid(changeset, "the provider refused the request: #{inspect(reason)}")
        end
    end
  end

  # An outcome that is not known (a create that may have happened) is settled by `lookup`
  # before anything is created again.
  defp reference(provider, context) do
    case provider.lookup(context) do
      {:ok, nil} -> provider.create(context)
      {:ok, ref} -> {:ok, ref}
      {:error, _} = error -> error
    end
  end

  defp notify_first(changeset, request, context) do
    opts = Internal.opts(changeset, context)

    changeset.resource
    |> Internal.signers(request.id, opts)
    |> Enum.filter(&(&1.order == 1))
    |> Enum.each(&(&1 |> Ash.Changeset.for_update(:notify, %{}, opts) |> Ash.update!()))

    {:ok, request}
  end

  defp invalid(changeset, message),
    do:
      Ash.Changeset.add_error(
        changeset,
        Ash.Error.Changes.InvalidChanges.exception(message: message)
      )
end
