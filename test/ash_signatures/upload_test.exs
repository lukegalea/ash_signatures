# SPDX-FileCopyrightText: 2026 Luke Galea
# SPDX-License-Identifier: MIT

defmodule AshSignatures.UploadTest do
  use AshSignatures.DataCase

  import AshSignatures.Test.Fixtures

  alias AshSignatures.Test.Domain

  test "the first signed copy completes the request" do
    %{request: request, source: source} = sent(provider: :upload)
    copy = version("SYNTHETIC signed on paper")

    request = Domain.receive_signed_copy!(request, copy.id, authorize?: false)

    assert request.status == :completed

    [document] =
      Domain.list_documents!(query: [filter: [request_id: request.id]], authorize?: false)

    assert document.source_sha256 == source.sha256
    assert {document.result_version_id, document.result_sha256} == {copy.id, copy.sha256}

    assert [
             %{type: :signed, route: :upload, signer_id: nil, sha256: sha256} | on_copy
           ] = events(request.id)

    assert sha256 == copy.sha256
    assert on_copy != []

    assert Enum.all?(
             on_copy,
             &match?(%{type: :signed, route: :upload, signer_id: id} when not is_nil(id), &1)
           )

    assert Enum.all?(on_copy, &(&1.sha256 == copy.sha256))

    [completion] =
      Domain.list_completions!(query: [filter: [request_id: request.id]], authorize?: false)

    assert [%{"result_sha256" => ^sha256}] = completion.record["documents"]
    assert Enum.all?(completion.record["signers"], &(&1["status"] == "signed"))
  end

  test "a paper request notifies no one: its signers wait, with no event, until the copy" do
    %{request: request, signers: signers} = sent(provider: :upload)

    assert events(request.id) == []
    assert Enum.all?(signers, &(signer(&1.id).status == :pending))
  end

  test "a person's act cannot reach a paper signer: none of them was told it is their turn" do
    %{signers: [first | _]} = sent(provider: :upload)

    assert {:error, _} = Domain.view(signer(first.id), authorize?: false)
    assert signer(first.id).status == :pending
  end

  test "a copy that completes an in-platform request signs the signers who had not signed, on it" do
    %{request: request, signers: [first, second]} = sent(provider: :recording)

    first.id |> signer() |> sign_through()

    copy = version("SYNTHETIC signed on paper by the second signer")

    request =
      request.id
      |> Domain.get_request!(authorize?: false)
      |> Domain.receive_signed_copy!(copy.id, authorize?: false)

    assert request.status == :completed
    assert signer(first.id).status == :signed
    assert signer(second.id).status == :signed

    signed = Enum.filter(events(request.id), &(&1.type == :signed))

    assert [%{signer_id: first_id, route: :in_platform}] =
             Enum.filter(signed, &(&1.route == :in_platform))

    assert first_id == first.id

    assert [%{signer_id: second_id, sha256: sha256}] =
             Enum.filter(signed, &(&1.route == :upload and &1.signer_id))

    assert {second_id, sha256} == {second.id, copy.sha256}
  end

  test "the same bytes again change nothing; different bytes are recorded and complete nothing" do
    %{request: request} = sent(provider: :upload)
    copy = version("SYNTHETIC signed on paper, once")

    request = Domain.receive_signed_copy!(request, copy.id, authorize?: false)
    events_after_first = events(request.id)

    request = Domain.receive_signed_copy!(request, copy.id, authorize?: false)
    assert events(request.id) == events_after_first

    later = version("SYNTHETIC signed on paper, a second time")
    request = Domain.receive_signed_copy!(request, later.id, authorize?: false)

    assert request.status == :completed
    assert length(events(request.id)) == length(events_after_first) + 1

    assert [_one] =
             Domain.list_completions!(
               query: [filter: [request_id: request.id]],
               authorize?: false
             )

    [document] =
      Domain.list_documents!(query: [filter: [request_id: request.id]], authorize?: false)

    assert document.result_sha256 == copy.sha256
  end

  test "a copy whose bytes are the unsigned document is refused" do
    %{request: request, source: source} = sent(provider: :upload)

    assert {:error, error} = Domain.receive_signed_copy(request, source.id, authorize?: false)
    assert Exception.message(error) =~ "unsigned"
  end

  test "a copy whose bytes are an unsigned document another request on the subject showed is refused" do
    subject = subject()
    earlier = version("SYNTHETIC consent form, first draft")
    %{request: _in_platform} = sent(subject: subject, version: earlier, provider: :recording)
    %{request: paper} = sent(subject: subject, provider: :upload, roles: [:patient])

    assert {:error, error} = Domain.receive_signed_copy(paper, earlier.id, authorize?: false)
    assert Exception.message(error) =~ "unsigned"
    assert Domain.get_request!(paper.id, authorize?: false).status == :sent
    assert events(paper.id) == []
  end

  test "an unsigned document of another subject is no reason to refuse a copy" do
    other = version("SYNTHETIC consent form of another visit")
    _ = sent(version: other, provider: :recording)
    %{request: paper} = sent(provider: :upload, roles: [:patient])

    assert Domain.receive_signed_copy!(paper, other.id, authorize?: false).status == :completed
  end

  test "a request with several documents completes when each has its copy" do
    %{request: request, signers: _} = draft(roles: [:patient])

    Domain.add_document!(%{request_id: request.id, source_version_id: version().id, position: 2},
      authorize?: false
    )

    request = Domain.send_request!(request, %{provider: :upload}, authorize?: false)

    [first, second] =
      Domain.list_documents!(
        query: [filter: [request_id: request.id], sort: [position: :asc]],
        authorize?: false
      )

    assert {:error, _} = Domain.receive_signed_copy(request, version().id, authorize?: false)

    request =
      Domain.receive_signed_copy!(request, version().id, %{request_document_id: first.id},
        authorize?: false
      )

    assert request.status == :sent

    request =
      Domain.receive_signed_copy!(request, version().id, %{request_document_id: second.id},
        authorize?: false
      )

    assert request.status == :completed
  end

  test "a copy arriving for the subject supersedes the other open request, whose signers are withdrawn" do
    subject = subject()
    %{request: in_platform, signers: signers} = sent(subject: subject, provider: :recording)
    %{request: paper} = sent(subject: subject, provider: :upload, roles: [:patient])

    Domain.receive_signed_copy!(paper, version().id, authorize?: false)

    assert Domain.get_request!(in_platform.id, authorize?: false).status == :superseded
    assert Enum.all?(signers, &(signer(&1.id).status == :withdrawn))
    assert_received {:provider, :void, _ref, :superseded}
  end

  test "a copy already received on one request is recognised on another request for the same subject" do
    subject = subject()
    copy = version("SYNTHETIC one paper copy")
    %{request: first} = sent(subject: subject, provider: :upload)
    Domain.receive_signed_copy!(first, copy.id, authorize?: false)

    %{request: second} = sent(subject: subject, provider: :upload)
    second = Domain.receive_signed_copy!(second, copy.id, authorize?: false)

    assert second.status == :sent
    assert events(second.id) == []
  end
end
