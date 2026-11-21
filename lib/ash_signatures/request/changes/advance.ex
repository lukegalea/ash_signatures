# SPDX-FileCopyrightText: 2026 Luke Galea
# SPDX-License-Identifier: MIT

defmodule AshSignatures.Request.Changes.Advance do
  @moduledoc """
  Moves a request on after a signer signs: `completed` when every signer has signed,
  otherwise `partially_signed` with the next signer notified. On completion, each document's
  last stamped version (`AshSignatures.Stamp`) becomes its signed result before the
  completion record is written.

  The update is fenced on the request still being open, so a request that ended meanwhile is
  not moved.
  """

  use Ash.Resource.Change

  import Ash.Expr

  alias AshSignatures.Internal
  alias AshSignatures.Request.Complete

  @impl true
  def change(changeset, _opts, context) do
    changeset
    |> Ash.Changeset.filter(expr(status in ^Internal.open_request_states()))
    |> Ash.Changeset.before_action(&decide(&1, context))
    |> Ash.Changeset.after_action(&follow(&1, &2, context))
  end

  defp decide(changeset, context) do
    opts = Internal.opts(changeset, context)
    signers = Internal.signers(changeset.resource, changeset.data.id, opts)

    if Enum.all?(signers, &(&1.status == :signed)) do
      changeset
      |> AshStateMachine.transition_state(:completed)
      |> Ash.Changeset.force_change_attribute(:ended_at, Internal.now())
    else
      AshStateMachine.transition_state(changeset, :partially_signed)
    end
  end

  defp follow(changeset, %{status: :completed} = request, context) do
    opts = Internal.opts(changeset, context)
    promote_stamped(changeset.resource, request, opts)
    Complete.run(changeset.resource, request, opts)
    {:ok, request}
  end

  defp follow(changeset, request, context) do
    opts = Internal.opts(changeset, context)

    changeset.resource
    |> Internal.signers(request.id, opts)
    |> Enum.find(&(&1.status == :pending))
    |> case do
      nil -> :ok
      next -> next |> Ash.Changeset.for_update(:notify, %{}, opts) |> Ash.update!()
    end

    {:ok, request}
  end

  defp promote_stamped(resource, request, opts) do
    for document <- Internal.documents(resource, request.id, opts),
        is_nil(document.result_version_id) and not is_nil(document.current_version_id) do
      document
      |> Ash.Changeset.for_update(
        :record_result,
        %{result_version_id: document.current_version_id, result_sha256: document.current_sha256},
        opts
      )
      |> Ash.update!()
    end

    :ok
  end
end
