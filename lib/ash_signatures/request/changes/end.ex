# SPDX-FileCopyrightText: 2026 Luke Galea
# SPDX-License-Identifier: MIT

defmodule AshSignatures.Request.Changes.End do
  @moduledoc """
  Ends a request that has not completed (`to:` `:returned`, `:recalled`, `:cancelled`,
  `:expired` or `:superseded`): signers who have not acted are withdrawn and the provider is
  told (`void`). Fenced on the request not having ended already.
  """

  use Ash.Resource.Change

  import Ash.Expr

  alias AshSignatures.Internal

  @impl true
  def init(opts) do
    if opts[:to] in [:returned, :recalled, :cancelled, :expired, :superseded],
      do: {:ok, opts},
      else: {:error, "`to` must be a state that ends a request without completing it"}
  end

  @impl true
  def change(changeset, opts, context) do
    changeset
    |> Ash.Changeset.filter(expr(status in [:draft, :sent, :partially_signed]))
    |> AshStateMachine.transition_state(opts[:to])
    |> Ash.Changeset.force_change_attribute(:ended_at, Internal.now())
    |> Ash.Changeset.after_action(fn changeset, request ->
      opts_ = Internal.opts(changeset, context)
      Internal.withdraw_open_signers(changeset.resource, request.id, opts_)

      case Internal.void(changeset.resource, request, opts[:to], opts_) do
        :ok ->
          {:ok, request}

        {:error, reason} ->
          {:error, "the provider could not void the request: #{inspect(reason)}"}
      end
    end)
  end
end
