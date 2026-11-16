# SPDX-FileCopyrightText: 2026 Luke Galea
# SPDX-License-Identifier: MIT

defmodule AshSignatures.Signer.Changes.Act do
  @moduledoc """
  One act on a signer's own row (`type:` the event it records): moves the signer's state,
  records the event and, for `signed`, `declined` and `changes_requested`, moves the request
  on. Fenced on the signer's status not having changed since it was read.
  """

  use Ash.Resource.Change

  import Ash.Expr

  alias AshSignatures.{Digest, Internal}
  alias AshSignatures.Request.Info

  @types [
    :notified,
    :viewed,
    :consented,
    :signed,
    :declined,
    :changes_requested,
    :reminded,
    :withdrawn
  ]

  @impl true
  def init(opts) do
    if opts[:type] in @types,
      do: {:ok, opts},
      else: {:error, "unknown signer act #{inspect(opts[:type])}"}
  end

  @impl true
  def change(changeset, opts, context) do
    type = opts[:type]
    signer = changeset.data

    changeset
    |> Ash.Changeset.filter(expr(status == ^signer.status))
    |> transition(type, signer)
    |> Ash.Changeset.before_action(&check_request(&1, type, context))
    |> Ash.Changeset.after_action(&follow(&1, &2, type, context))
  end

  defp transition(changeset, :notified, _signer),
    do: changeset |> AshStateMachine.transition_state(:notified) |> stamp(:notified_at)

  defp transition(changeset, :viewed, signer) do
    changeset = AshStateMachine.transition_state(changeset, :viewed)
    if signer.viewed_at, do: changeset, else: stamp(changeset, :viewed_at)
  end

  defp transition(changeset, :consented, %{status: :viewed}), do: stamp(changeset, :consented_at)

  defp transition(changeset, :consented, _signer),
    do: invalid(changeset, "the signer must view the documents before consenting")

  defp transition(changeset, :signed, %{consented_at: nil}),
    do: invalid(changeset, "the signer has not consented to sign electronically")

  defp transition(changeset, :signed, _signer),
    do: changeset |> AshStateMachine.transition_state(:signed) |> stamp(:signed_at)

  defp transition(changeset, :reminded, %{status: status}) when status in [:notified, :viewed],
    do: changeset

  defp transition(changeset, :reminded, _signer),
    do: invalid(changeset, "only the signer whose turn it is can be reminded")

  defp transition(changeset, type, _signer)
       when type in [:declined, :changes_requested, :withdrawn],
       do: changeset |> AshStateMachine.transition_state(type) |> stamp(:ended_at)

  # The request is read once, before the write: an act on a request that has passed its
  # `expires_at` is refused, and a signature records the hash of what was shown.
  defp check_request(changeset, type, context)
       when type in [:viewed, :consented, :signed, :declined, :changes_requested] do
    opts = Internal.opts(changeset, context)
    request_resource = AshSignatures.Member.Dsl.request(changeset.resource)
    request = Internal.get_request!(request_resource, changeset.data.request_id, opts)

    cond do
      request.expires_at && DateTime.compare(Internal.now(), request.expires_at) != :lt ->
        invalid(changeset, "the request expired at #{DateTime.to_iso8601(request.expires_at)}")

      type == :signed ->
        shown =
          request_resource
          |> Internal.documents(request.id, opts)
          |> Enum.map(& &1.source_sha256)
          |> Digest.shown()

        Ash.Changeset.force_change_attribute(changeset, :shown_sha256, shown)

      true ->
        changeset
    end
  end

  defp check_request(changeset, _type, _context), do: changeset

  defp follow(changeset, signer, type, context) do
    opts = Internal.opts(changeset, context)
    request_resource = AshSignatures.Member.Dsl.request(changeset.resource)

    if type != :notified do
      Internal.record_event(request_resource, event(changeset, signer, type), opts)
    end

    case type do
      :signed ->
        move_request(request_resource, signer, :advance, opts)

      type when type in [:declined, :changes_requested] ->
        move_request(request_resource, signer, :return, opts)

      :reminded ->
        remind(request_resource, signer, opts)

      _ ->
        {:ok, signer}
    end
  end

  defp event(changeset, signer, type) do
    %{
      request_id: signer.request_id,
      signer_id: signer.id,
      type: type,
      route:
        if(type in [:viewed, :consented, :signed, :declined, :changes_requested],
          do: :in_platform
        ),
      sha256: if(type == :signed, do: signer.shown_sha256),
      ip_address: argument(changeset, :ip_address),
      user_agent: argument(changeset, :user_agent),
      reason: argument(changeset, :reason)
    }
  end

  defp argument(changeset, name) do
    if Ash.Resource.Info.action_input?(changeset.resource, changeset.action.name, name),
      do: Ash.Changeset.get_argument(changeset, name)
  end

  defp move_request(request_resource, signer, action, opts) do
    request_resource
    |> Internal.get_request!(signer.request_id, opts)
    |> Ash.Changeset.for_update(action, %{}, opts)
    |> Ash.update!()

    {:ok, signer}
  end

  defp remind(request_resource, signer, opts) do
    request = Internal.get_request!(request_resource, signer.request_id, opts)

    with ref when is_binary(ref) <- request.provider_ref,
         provider when not is_nil(provider) <- Info.provider(request_resource, request.provider) do
      case provider.remind(ref, signer, Internal.provider_context(request, opts)) do
        :ok ->
          {:ok, signer}

        {:error, reason} ->
          {:error, "the provider could not send the reminder: #{inspect(reason)}"}
      end
    else
      _ -> {:ok, signer}
    end
  end

  defp stamp(changeset, attribute),
    do: Ash.Changeset.force_change_attribute(changeset, attribute, Internal.now())

  defp invalid(changeset, message),
    do:
      Ash.Changeset.add_error(
        changeset,
        Ash.Error.Changes.InvalidChanges.exception(message: message)
      )
end
