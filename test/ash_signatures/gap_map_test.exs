# SPDX-FileCopyrightText: 2026 Luke Galea
# SPDX-License-Identifier: MIT

defmodule AshSignatures.GapMapTest do
  @moduledoc """
  Probes for the gap map in the decision record that placed this package: each row the
  package claims is called here, so the map is checked by a test rather than by reading.
  """

  use AshSignatures.DataCase

  import AshSignatures.Test.Fixtures

  alias AshSignatures.Test.{Completion, Request, RequestDocument, Signer, SignerEvent}

  test "immutable document bytes and hash: the source hash is copied from the version when added" do
    %{request: request, source: source} = draft()

    [document] =
      Ash.read!(RequestDocument, authorize?: false) |> Enum.filter(&(&1.request_id == request.id))

    assert document.source_sha256 == source.sha256
  end

  test "the link from a draft version to its signed version is on the request document row" do
    attributes = RequestDocument |> Ash.Resource.Info.attributes() |> Enum.map(& &1.name)
    assert [:source_version_id, :result_version_id] -- attributes == []
  end

  test "states come from ash_state_machine" do
    assert AshStateMachine.Info.state_machine_all_states(Request) |> Enum.sort() ==
             Enum.sort([
               :draft,
               :sent,
               :partially_signed,
               :completed,
               :returned,
               :recalled,
               :cancelled,
               :expired,
               :superseded
             ])

    assert AshStateMachine.Info.state_machine_all_states(Signer) |> Enum.sort() ==
             Enum.sort([
               :pending,
               :notified,
               :viewed,
               :signed,
               :declined,
               :changes_requested,
               :withdrawn
             ])
  end

  test "signer personal data is marked for the host to seal, and nothing else is" do
    for {kind, resource} <- [signer: Signer, signer_event: SignerEvent] do
      sensitive =
        resource
        |> Ash.Resource.Info.attributes()
        |> Enum.filter(& &1.sensitive?)
        |> Enum.map(& &1.name)
        |> Enum.sort()

      assert sensitive == Enum.sort(AshSignatures.payload_fields(kind))
    end

    assert Completion |> Ash.Resource.Info.attributes() |> Enum.reject(& &1.sensitive?) ==
             Ash.Resource.Info.attributes(Completion)
  end

  test "the event log is append-only: no update or destroy action" do
    assert SignerEvent |> Ash.Resource.Info.actions() |> Enum.map(& &1.type) |> Enum.sort() == [
             :create,
             :read
           ]

    assert Completion |> Ash.Resource.Info.actions() |> Enum.map(& &1.type) |> Enum.sort() == [
             :create,
             :read
           ]
  end

  test "the provider behaviour has the six asynchronous callbacks and both shipped providers implement it" do
    optional = AshSignatures.Provider.behaviour_info(:optional_callbacks) |> Keyword.keys()

    callbacks =
      AshSignatures.Provider.behaviour_info(:callbacks)
      |> Keyword.keys()
      |> Kernel.--(optional)
      |> Enum.sort()

    assert callbacks == [:create, :fetch, :lookup, :observe, :remind, :void]
    assert optional == [:notifies_signers?]

    for provider <- [AshSignatures.Providers.InPlatform, AshSignatures.Providers.Upload] do
      behaviours =
        provider.module_info(:attributes) |> Keyword.get_values(:behaviour) |> List.flatten()

      assert AshSignatures.Provider in behaviours
    end
  end

  test "a provider that does not implement the behaviour is reported when the resource compiles" do
    output =
      ExUnit.CaptureIO.capture_io(:stderr, fn ->
        defmodule BadHost.Request do
          use Ash.Resource,
            domain: nil,
            fragments: [AshSignatures.Request],
            validate_domain_inclusion?: false

          signature_request do
            request_document(AshSignatures.Test.RequestDocument)
            signer(AshSignatures.Test.Signer)
            signer_event(AshSignatures.Test.SignerEvent)
            completion(AshSignatures.Test.Completion)
            document_version(AshSignatures.Test.DocumentVersion)
            providers in_platform: String
          end
        end
      end)

    assert output =~ "these providers do not implement AshSignatures.Provider: [:in_platform]"
  end
end
