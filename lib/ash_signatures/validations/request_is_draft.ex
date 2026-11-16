# SPDX-FileCopyrightText: 2026 Luke Galea
# SPDX-License-Identifier: MIT

defmodule AshSignatures.Validations.RequestIsDraft do
  @moduledoc """
  Refuses to add a document or a signer to a request that has been sent. Use it on any
  create action a host adds to its request document or signer resource.
  """

  use Ash.Resource.Validation

  alias AshSignatures.Internal

  @impl true
  def validate(changeset, _opts, context) do
    request_resource = AshSignatures.Member.Dsl.request(changeset.resource)

    case Ash.Changeset.get_attribute(changeset, :request_id) do
      nil ->
        :ok

      request_id ->
        opts = [actor: context.actor, tenant: changeset.tenant, authorize?: false]

        case Internal.get_request!(request_resource, request_id, opts) do
          %{status: :draft} ->
            :ok

          _ ->
            {:error,
             field: :request_id, message: "the request has been sent and can no longer change"}
        end
    end
  end
end
