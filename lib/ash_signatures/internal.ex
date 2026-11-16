# SPDX-FileCopyrightText: 2026 Luke Galea
# SPDX-License-Identifier: MIT

defmodule AshSignatures.Internal do
  @moduledoc false
  # Reads and writes a request's sibling rows on behalf of the fragments' actions.
  #
  # These are the consequences of an act the host has already authorized (a signer
  # signing, a person recalling a request): the request moving on, an event being
  # recorded, the completion being written. They run with the acting actor and tenant
  # and with `authorize?: false`, so the host's policies decide who may act, not who
  # may cause the bookkeeping that follows.

  require Ash.Query

  alias AshSignatures.Request.Info

  @open_request [:sent, :partially_signed]
  @open_signer [:pending, :notified, :viewed]

  def open_request_states, do: @open_request
  def open_signer_states, do: @open_signer

  def opts(changeset, context) do
    [actor: context.actor, tenant: changeset.tenant, authorize?: false]
  end

  def get_request!(request_resource, id, opts) do
    request_resource
    |> Ash.Query.for_read(:read, %{}, opts)
    |> Ash.Query.filter(id == ^id)
    |> Ash.read_one!()
    |> case do
      nil -> raise Ash.Error.Query.NotFound, primary_key: %{id: id}, resource: request_resource
      request -> request
    end
  end

  def documents(request_resource, request_id, opts) do
    request_resource
    |> Info.request_document()
    |> Ash.Query.for_read(:read, %{}, opts)
    |> Ash.Query.filter(request_id == ^request_id)
    |> Ash.Query.sort(position: :asc)
    |> Ash.read!()
  end

  def signers(request_resource, request_id, opts) do
    request_resource
    |> Info.signer()
    |> Ash.Query.for_read(:read, %{}, opts)
    |> Ash.Query.filter(request_id == ^request_id)
    |> Ash.Query.sort(order: :asc)
    |> Ash.read!()
  end

  def events(request_resource, request_id, opts) do
    request_resource
    |> Info.signer_event()
    |> Ash.Query.for_read(:read, %{}, opts)
    |> Ash.Query.filter(request_id == ^request_id)
    |> Ash.Query.sort(occurred_at: :asc, id: :asc)
    |> Ash.read!()
  end

  def record_event(request_resource, attrs, opts) do
    request_resource
    |> Info.signer_event()
    |> Ash.Changeset.for_create(:record, attrs, opts)
    |> Ash.create!()
  end

  def version_sha256(request_resource, version_id, opts) do
    request_resource
    |> Info.document_version()
    |> Ash.Query.for_read(:read, %{}, opts)
    |> Ash.Query.filter(id == ^version_id)
    |> Ash.read_one!()
    |> case do
      %{sha256: sha256} when is_binary(sha256) -> {:ok, sha256}
      _ -> {:error, "no document version #{version_id} with a sha256"}
    end
  end

  def provider_context(request, opts),
    do: %{request: request, actor: opts[:actor], tenant: opts[:tenant]}

  # Withdraws every signer of the request who has not acted, recording a `withdrawn`
  # event for each.
  def withdraw_open_signers(request_resource, request_id, opts) do
    for signer <- signers(request_resource, request_id, opts),
        signer.status in @open_signer do
      signer
      |> Ash.Changeset.for_update(:withdraw, %{}, opts)
      |> Ash.update!()
    end

    :ok
  end

  # Tells the provider a sent request ended without completing.
  def void(request_resource, request, reason, opts) do
    with ref when is_binary(ref) <- request.provider_ref,
         provider when not is_nil(provider) <- Info.provider(request_resource, request.provider) do
      provider.void(ref, reason, provider_context(request, opts))
    else
      _ -> :ok
    end
  end

  def now, do: DateTime.utc_now()
end
