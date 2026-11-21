# SPDX-FileCopyrightText: 2026 Luke Galea
# SPDX-License-Identifier: MIT

defmodule AshSignatures.StampTest do
  @moduledoc """
  A host that stamps in-platform signatures into the documents (`AshSignatures.Stamp`), what
  a signer types when signing, and the link events (`notified`, `delivered`). The refusals
  come first.
  """

  use AshSignatures.DataCase

  import AshSignatures.Test.Fixtures

  alias AshSignatures.SignerEvent.Changes.Hash
  alias AshSignatures.Test.Domain

  @typed %{
    signed_name: "SYNTHETIC Pat Patient",
    signed_title: "SYNTHETIC guardian",
    authority: "SYNTHETIC I may sign for the patient"
  }

  defp documents(request_id),
    do: Domain.list_documents!(query: [filter: [request_id: request_id]], authorize?: false)

  defp completion(request_id) do
    [completion] =
      Domain.list_completions!(query: [filter: [request_id: request_id]], authorize?: false)

    completion
  end

  describe "refused" do
    test "a stamp that fails fails the signature: nothing is signed or recorded" do
      %{request: request, signers: [patient]} =
        sent(subject_type: "stamped-visit", roles: [:patient])

      assert_raise Ash.Error.Invalid, ~r/could not be stamped/, fn ->
        sign_through(signer(patient.id), %{signed_name: "SYNTHETIC unstampable"})
      end

      # The view and consent before it stand; the signature does not.
      assert signer(patient.id).status == :viewed
      assert Domain.get_request!(request.id, authorize?: false).status == :sent
      refute Enum.any?(events(request.id), &(&1.type == :signed))
      assert [%{current_version_id: nil, result_version_id: nil}] = documents(request.id)
    end

    test "a blank typed field is recorded as absent" do
      %{request: request, signers: [patient]} = sent(roles: [:patient])
      sign_through(signer(patient.id), %{signed_name: "  "})

      assert %{signed_name: nil} = Enum.find(events(request.id), &(&1.type == :signed))
    end

    test "a send, a delivery or a bounce is recorded only while it is the signer's turn" do
      %{request: request, signers: [patient, clinician]} = sent()

      for record <- [&Domain.record_send/2, &Domain.record_delivery/2, &Domain.record_bounce/2] do
        assert {:error, error} = record.(signer(clinician.id), authorize?: false)
        assert Exception.message(error) =~ "turn"
      end

      sign_through(signer(patient.id))

      for record <- [&Domain.record_send/2, &Domain.record_delivery/2, &Domain.record_bounce/2] do
        assert {:error, _} = record.(signer(patient.id), authorize?: false)
      end

      refute Enum.any?(events(request.id), &(&1.type in [:sent, :delivered, :bounced]))
    end

    test "a version stamped part way through is not a signed copy, on any request on the subject" do
      subject = subject()

      %{request: request, signers: [patient, clinician]} =
        sent(subject: subject, subject_type: "stamped-visit")

      sign_through(signer(patient.id), @typed)
      [%{current_version_id: partly}] = documents(request.id)

      %{request: paper} =
        sent(
          subject: subject,
          subject_type: "stamped-visit",
          provider: :upload,
          roles: [:patient]
        )

      for target <- [paper, request] do
        assert {:error, error} =
                 Domain.receive_signed_copy(
                   Domain.get_request!(target.id, authorize?: false),
                   partly,
                   authorize?: false
                 )

        assert Exception.message(error) =~ "partly signed"
      end

      assert Domain.get_request!(paper.id, authorize?: false).status == :sent
      assert events(paper.id) == []

      # Completed, the version the second signer was shown is still only partly signed.
      sign_through(signer(clinician.id), @typed)
      completed = Domain.get_request!(request.id, authorize?: false)
      assert completed.status == :completed

      assert {:error, error} = Domain.receive_signed_copy(completed, partly, authorize?: false)
      assert Exception.message(error) =~ "partly signed"
    end

    test "a completed request's stamped result arriving as a copy changes nothing" do
      %{request: request, signers: [patient, clinician]} = sent(subject_type: "stamped-visit")
      sign_through(signer(patient.id), @typed)
      sign_through(signer(clinician.id), @typed)

      [%{result_version_id: result}] = documents(request.id)
      before = events(request.id)
      completed = Domain.get_request!(request.id, authorize?: false)

      assert %{status: :completed} =
               Domain.receive_signed_copy!(completed, result, authorize?: false)

      assert events(request.id) == before
    end
  end

  describe "a host that stamps" do
    test "each signer is shown the document with the signatures before theirs, and the last stamp is the result" do
      %{request: request, source: source, signers: [patient, clinician]} =
        sent(subject_type: "stamped-visit")

      patient = sign_through(signer(patient.id), @typed)
      assert patient.shown_sha256 == source.sha256

      [document] = documents(request.id)
      first_stamp = document.current_sha256
      assert is_binary(first_stamp) and first_stamp != source.sha256
      assert document.result_version_id == nil

      clinician = sign_through(signer(clinician.id), %{signed_name: "SYNTHETIC Dr Clinician"})
      assert clinician.shown_sha256 == first_stamp

      [document] = documents(request.id)
      assert document.result_sha256 == document.current_sha256
      assert document.result_version_id == document.current_version_id
      refute document.result_sha256 in [source.sha256, first_stamp]

      assert [%{"source_sha256" => source_sha, "result_sha256" => result_sha}] =
               completion(request.id).record["documents"]

      assert {source_sha, result_sha} == {source.sha256, document.result_sha256}
      assert AshSignatures.Completion.intact?(completion(request.id))
    end

    test "a request the stamp leaves unchanged completes with no result, as before" do
      %{request: request, source: source, signers: [patient]} = sent(roles: [:patient])
      patient = sign_through(signer(patient.id), @typed)

      assert patient.shown_sha256 == source.sha256
      assert [%{current_version_id: nil, result_version_id: nil}] = documents(request.id)
    end
  end

  describe "what the signer typed" do
    test "goes on the signed event, and its hash covers it" do
      %{request: request, signers: [patient]} = sent(roles: [:patient])
      sign_through(signer(patient.id), @typed)

      signed = Enum.find(events(request.id), &(&1.type == :signed))
      assert Map.take(signed, Map.keys(@typed)) == @typed
      assert is_binary(signed.salt)
      assert signed.event_hash == Hash.hash(signed)
      refute signed.event_hash == Hash.hash(%{signed | signed_title: "SYNTHETIC other"})
    end

    test "an event with none of them hashes as an event did before they existed" do
      %{request: request, signers: [patient]} = sent(roles: [:patient])
      sign_through(signer(patient.id))

      signed = Enum.find(events(request.id), &(&1.type == :signed))

      before =
        signed
        |> Map.take([:occurred_at, :request_id, :signer_id, :type, :route, :sha256])
        |> Map.merge(%{ip_address: signed.ip_address, user_agent: signed.user_agent, reason: nil})
        |> Map.put(:salt, signed.salt)

      assert signed.event_hash == AshSignatures.Digest.sha256_hex(before)
    end

    test "is listed among the fields a host seals" do
      fields = AshSignatures.payload_fields(:signer_event)
      assert [:signed_name, :signed_title, :authority] -- fields == []
      assert List.last(fields) == :salt
    end

    test "stays out of the completion record" do
      %{request: request, signers: [patient]} = sent(roles: [:patient])
      sign_through(signer(patient.id), @typed)

      json = Jason.encode!(completion(request.id).record)

      for value <- Map.values(@typed), do: refute(json =~ value)
    end
  end

  describe "the link events" do
    test "the signer whose turn it is gets a notified event, and a reported send and delivery are recorded" do
      %{request: request, signers: [patient, clinician]} = sent()
      assert Enum.map(events(request.id), & &1.type) == [:notified]

      sent = Domain.record_send!(signer(patient.id), authorize?: false)
      assert sent.status == :notified
      delivered = Domain.record_delivery!(signer(patient.id), authorize?: false)
      assert delivered.status == :notified

      sign_through(signer(patient.id))

      assert Enum.map(events(request.id), &{&1.type, &1.signer_id, &1.route}) == [
               {:notified, patient.id, nil},
               {:sent, patient.id, nil},
               {:delivered, patient.id, nil},
               {:viewed, patient.id, :in_platform},
               {:consented, patient.id, :in_platform},
               {:signed, patient.id, :in_platform},
               {:notified, clinician.id, nil}
             ]

      for event <- events(request.id), event.type in [:notified, :sent, :delivered] do
        assert event.salt == nil and event.ip_address == nil
        assert event.event_hash == Hash.hash(event)
      end
    end
  end
end
