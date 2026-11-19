# SPDX-FileCopyrightText: 2026 Luke Galea
# SPDX-License-Identifier: MIT

defmodule AshSignatures.SealedEventTest do
  use ExUnit.Case, async: true

  alias AshSignatures.SignerEvent.Changes.Hash
  alias AshSignatures.Test.{Domain, SealedSignerEvent}

  @payload %{
    ip_address: "192.0.2.10",
    user_agent: "SYNTHETIC-agent",
    reason: "SYNTHETIC wrong date"
  }

  defp record(payload) do
    Domain.record_sealed_event!(
      Map.merge(
        %{
          request_id: Ash.UUIDv7.generate(),
          signer_id: Ash.UUIDv7.generate(),
          type: :declined,
          route: :in_platform
        },
        payload
      ),
      authorize?: false
    )
  end

  test "a sealed host's event hash covers the personal fields it sealed" do
    event = record(@payload)

    assert Base.decode64!(event.encrypted_ip_address) =~ "SEALED:"
    assert event.ip_address == @payload.ip_address
    assert event.reason == @payload.reason
    assert event.event_hash == Hash.hash(event)
  end

  test "the hash changes with a personal field, so it is not taken without them" do
    event = record(@payload)
    other = record(%{@payload | ip_address: "192.0.2.11"})

    assert event.event_hash != Hash.hash(%{event | ip_address: nil, user_agent: nil, reason: nil})
    assert other.event_hash == Hash.hash(other)
  end

  # The package records `reminded` and `withdrawn` events with none of them.
  test "an event recorded with none of them hashes them as absent" do
    event = record(%{})

    assert event.ip_address == nil
    assert event.event_hash == Hash.hash(event)
  end

  test "the resource has no plaintext column for them" do
    attributes = Ash.Resource.Info.attribute_names(SealedSignerEvent)

    for field <- AshSignatures.payload_fields(:signer_event) do
      refute MapSet.member?(attributes, field)
      assert MapSet.member?(attributes, :"encrypted_#{field}")
    end
  end
end
