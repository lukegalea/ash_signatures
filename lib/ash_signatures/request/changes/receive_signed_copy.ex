# SPDX-FileCopyrightText: 2026 Luke Galea
# SPDX-License-Identifier: MIT

defmodule AshSignatures.Request.Changes.ReceiveSignedCopy do
  @moduledoc """
  Records a signed copy that arrived as a document version. See "Signed copies" in
  `AshSignatures.Request`.
  """

  use Ash.Resource.Change

  import Ash.Expr

  require Ash.Query

  alias AshSignatures.Internal
  alias AshSignatures.Request.{Complete, Info}

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.before_action(changeset, &receive_copy(&1, context))
  end

  defp receive_copy(changeset, context) do
    opts = Internal.opts(changeset, context)
    resource = changeset.resource
    request = changeset.data
    version_id = Ash.Changeset.get_argument(changeset, :version_id)
    documents = Internal.documents(resource, request.id, opts)

    with {:ok, sha256} <- Internal.version_sha256(resource, version_id, opts),
         {:ok, document} <-
           target(documents, Ash.Changeset.get_argument(changeset, :request_document_id)),
         request_ids = subject_request_ids(resource, request, opts),
         :ok <- signed?(resource, request_ids, sha256, opts) do
      if duplicate?(resource, request_ids, sha256, opts) do
        changeset
      else
        Internal.record_event(
          resource,
          %{
            request_id: request.id,
            type: :signed,
            route: :upload,
            sha256: sha256,
            ip_address: Ash.Changeset.get_argument(changeset, :ip_address),
            user_agent: Ash.Changeset.get_argument(changeset, :user_agent)
          },
          opts
        )

        maybe_complete(changeset, document, version_id, sha256, opts)
      end
    else
      {:error, message} ->
        Ash.Changeset.add_error(
          changeset,
          Ash.Error.Changes.InvalidArgument.exception(field: :version_id, message: message)
        )
    end
  end

  defp target([only], nil), do: {:ok, only}

  defp target(_documents, nil),
    do: {:error, "the request has several documents; name one with request_document_id"}

  defp target(documents, id) do
    case Enum.find(documents, &(&1.id == id)) do
      nil -> {:error, "#{id} is not one of this request's documents"}
      document -> {:ok, document}
    end
  end

  # Every request on the same subject, this one included.
  defp subject_request_ids(resource, request, opts) do
    resource
    |> Ash.Query.for_read(:read, %{}, opts)
    |> Ash.Query.filter(
      subject_type == ^request.subject_type and subject_id == ^request.subject_id
    )
    |> Ash.Query.select([:id])
    |> Ash.read!()
    |> Enum.map(& &1.id)
  end

  # A copy whose bytes are a document any of the subject's requests showed unsigned is not a
  # signed copy: an earlier draft of the subject is refused as much as this request's own.
  defp signed?(resource, request_ids, sha256, opts) do
    unsigned? =
      resource
      |> Info.request_document()
      |> Ash.Query.for_read(:read, %{}, opts)
      |> Ash.Query.filter(request_id in ^request_ids and source_sha256 == ^sha256)
      |> Ash.exists?()

    if unsigned?, do: {:error, "the copy is the unsigned document"}, else: :ok
  end

  # A copy already received for the same subject, on any request, changes nothing.
  defp duplicate?(resource, request_ids, sha256, opts) do
    resource
    |> Info.signer_event()
    |> Ash.Query.for_read(:read, %{}, opts)
    |> Ash.Query.filter(
      request_id in ^request_ids and type == :signed and route == :upload and sha256 == ^sha256
    )
    |> Ash.exists?()
  end

  defp maybe_complete(changeset, document, version_id, sha256, opts) do
    open? = changeset.data.status in Internal.open_request_states()

    if open? and is_nil(document.result_sha256) do
      document
      |> Ash.Changeset.for_update(
        :record_result,
        %{result_version_id: version_id, result_sha256: sha256},
        opts
      )
      |> Ash.update!()
    end

    complete? =
      open? and
        changeset.resource
        |> Internal.documents(changeset.data.id, opts)
        |> Enum.all?(&is_binary(&1.result_sha256))

    if complete? do
      changeset
      |> Ash.Changeset.filter(expr(status in ^Internal.open_request_states()))
      |> AshStateMachine.transition_state(:completed)
      |> Ash.Changeset.force_change_attribute(:ended_at, Internal.now())
      |> Ash.Changeset.after_action(fn changeset, request ->
        Complete.run(changeset.resource, request, opts)
        {:ok, request}
      end)
    else
      changeset
    end
  end
end
