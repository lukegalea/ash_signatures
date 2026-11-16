# SPDX-FileCopyrightText: 2026 Luke Galea
# SPDX-License-Identifier: MIT

defmodule AshSignatures.InPlatformTest do
  use AshSignatures.DataCase

  import AshSignatures.Test.Fixtures

  alias AshSignatures.Test.Domain

  describe "send" do
    test "fixes the digest, takes the provider's reference and notifies only the first signer" do
      %{request: request, source: source, signers: [patient, clinician]} = sent()

      assert request.status == :sent
      assert request.provider == :in_platform
      assert request.provider_ref == "in_platform:#{request.id}"

      assert request.documents_digest ==
               AshSignatures.Digest.sha256_hex(%{
                 documents: [source.sha256],
                 signers: [%{role: :patient, order: 1}, %{role: :clinician, order: 2}]
               })

      assert signer(patient.id).status == :notified
      assert signer(clinician.id).status == :pending
    end

    test "refuses a request with no signers, or with a gap in their order" do
      %{request: request} = draft(roles: [])
      assert {:error, error} = Domain.send_request(request, authorize?: false)
      assert Exception.message(error) =~ "at least one signer"

      %{request: gapped} = draft(roles: [:patient])

      Domain.add_signer!(%{request_id: gapped.id, role: :clinician, order: 3}, authorize?: false)
      assert {:error, error} = Domain.send_request(gapped, authorize?: false)
      assert Exception.message(error) =~ "no gaps"
    end

    test "refuses a provider the request does not name" do
      %{request: request} = draft()

      assert {:error, error} =
               Domain.send_request(request, %{provider: :courier}, authorize?: false)

      assert Exception.message(error) =~ "providers"
    end

    test "nothing can be added once the request is sent" do
      %{request: request} = sent()

      assert {:error, error} =
               Domain.add_signer(%{request_id: request.id, role: :witness, order: 3},
                 authorize?: false
               )

      assert Exception.message(error) =~ "has been sent"

      assert {:error, _} =
               Domain.add_document(
                 %{request_id: request.id, source_version_id: version().id, position: 2},
                 authorize?: false
               )
    end
  end

  describe "the provider seam" do
    test "lookup runs before create, and an existing reference is reused rather than created again" do
      %{request: request} = draft()
      Process.put(:recording_lookup, "recording:from-an-earlier-attempt")

      request = Domain.send_request!(request, %{provider: :recording}, authorize?: false)

      assert_received {:provider, :lookup, _}
      refute_received {:provider, :create, _}
      assert request.provider_ref == "recording:from-an-earlier-attempt"
    end

    test "with no reference to find, create is called once" do
      %{request: request} = draft()
      request = Domain.send_request!(request, %{provider: :recording}, authorize?: false)

      assert_received {:provider, :lookup, id}
      assert_received {:provider, :create, ^id}
      assert request.provider_ref == "recording:#{request.id}"
    end
  end

  describe "signing in order" do
    test "the signers sign in turn, and the request completes with one record" do
      %{request: request, source: source, signers: [patient, clinician]} = sent()

      patient = sign_through(signer(patient.id))
      assert patient.status == :signed
      assert patient.shown_sha256 == source.sha256

      assert Domain.get_request!(request.id, authorize?: false).status == :partially_signed
      assert signer(clinician.id).status == :notified

      sign_through(signer(clinician.id))

      request = Domain.get_request!(request.id, authorize?: false)
      assert request.status == :completed
      assert request.ended_at

      assert [completion] =
               Domain.list_completions!(
                 query: [filter: [request_id: request.id]],
                 authorize?: false
               )

      assert AshSignatures.Completion.intact?(completion)
      assert completion.chain_head == "SYNTHETIC-chain-head"
      assert completion.record["request"]["documents_digest"] == request.documents_digest

      assert [%{"source_sha256" => sha256, "result_sha256" => nil}] =
               completion.record["documents"]

      assert sha256 == source.sha256

      assert Enum.map(completion.record["signers"], &{&1["role"], &1["status"]}) ==
               [{"patient", "signed"}, {"clinician", "signed"}]

      events = events(request.id)

      assert Enum.map(events, & &1.type) ==
               [:viewed, :consented, :signed, :viewed, :consented, :signed]

      assert Enum.map(completion.record["events"], & &1["event_hash"]) ==
               Enum.map(events, & &1.event_hash)

      for event <- events do
        assert event.event_hash == AshSignatures.SignerEvent.Changes.Hash.hash(event)
      end
    end

    test "the record holds no personal data" do
      %{request: request, signers: [patient]} = sent(roles: [:patient])
      sign_through(signer(patient.id))

      [completion] =
        Domain.list_completions!(query: [filter: [request_id: request.id]], authorize?: false)

      encoded = Jason.encode!(completion.record)

      refute encoded =~ "SYNTHETIC patient"
      refute encoded =~ "@example.test"
      refute encoded =~ "192.0.2.10"
    end

    test "a signer whose turn it is not cannot act" do
      %{signers: [_patient, clinician]} = sent()
      assert {:error, _} = Domain.view(signer(clinician.id), authorize?: false)
    end

    test "signing needs consent first" do
      %{signers: [patient, _]} = sent()
      viewed = Domain.view!(signer(patient.id), authorize?: false)

      assert {:error, error} = Domain.sign(viewed, authorize?: false)
      assert Exception.message(error) =~ "consented"
    end

    test "a signer signs what they were shown: several documents hash together, in position order" do
      %{request: request, source: first, signers: [patient]} = draft(roles: [:patient])
      second = version()

      Domain.add_document!(%{request_id: request.id, source_version_id: second.id, position: 2},
        authorize?: false
      )

      Domain.send_request!(request, authorize?: false)

      patient = sign_through(signer(patient.id))

      assert patient.shown_sha256 ==
               AshSignatures.Digest.sha256_hex([first.sha256, second.sha256])
    end

    test "an act after the request's expires_at is refused" do
      past = DateTime.add(DateTime.utc_now(), -60, :second)
      %{signers: [patient, _]} = sent(expires_at: past)

      assert {:error, error} = Domain.view(signer(patient.id), authorize?: false)
      assert Exception.message(error) =~ "expired"
    end
  end

  describe "a request that ends without completing" do
    test "a decline needs a reason and returns the request; the others are withdrawn and the provider told" do
      %{request: request, signers: [patient, clinician]} = sent(provider: :recording)

      assert {:error, _} = Domain.decline(signer(patient.id), "", authorize?: false)

      declined =
        signer(patient.id)
        |> Domain.view!(authorize?: false)
        |> Domain.decline!("SYNTHETIC: the dosage is wrong", authorize?: false)

      assert declined.status == :declined
      assert Domain.get_request!(request.id, authorize?: false).status == :returned
      assert signer(clinician.id).status == :withdrawn
      assert_received {:provider, :void, _ref, :returned}

      assert Enum.map(events(request.id), & &1.type) == [:viewed, :declined, :withdrawn]
      assert Enum.at(events(request.id), 1).reason == "SYNTHETIC: the dosage is wrong"
    end

    test "a change request returns the request too" do
      %{request: request, signers: [patient, _]} = sent()

      signer(patient.id)
      |> Domain.view!(authorize?: false)
      |> Domain.request_changes!("SYNTHETIC: wrong clinic address", authorize?: false)

      assert Domain.get_request!(request.id, authorize?: false).status == :returned
    end

    test "recall, cancel and expire end the request and withdraw who has not acted" do
      for {action, status} <- [
            recall_request: :recalled,
            cancel_request: :cancelled,
            expire_request: :expired
          ] do
        %{request: request, signers: signers} = sent(provider: :recording)
        ended = apply(Domain, :"#{action}!", [request, [authorize?: false]])

        assert ended.status == status
        assert Enum.all?(signers, &(signer(&1.id).status == :withdrawn))
        assert_received {:provider, :void, _ref, ^status}
      end
    end

    test "a request that has ended cannot end again" do
      %{request: request} = sent()
      recalled = Domain.recall_request!(request, authorize?: false)
      assert {:error, _} = Domain.cancel_request(recalled, authorize?: false)
    end
  end

  test "a reminder is an event and a provider call, and changes no state" do
    %{request: request, signers: [patient, clinician]} = sent(provider: :recording)

    reminded = Domain.remind!(signer(patient.id), authorize?: false)
    assert reminded.status == :notified
    assert_received {:provider, :remind, _ref, id} when id == patient.id

    assert {:error, _} = Domain.remind(signer(clinician.id), authorize?: false)
    assert Enum.map(events(request.id), & &1.type) == [:reminded]
  end
end
