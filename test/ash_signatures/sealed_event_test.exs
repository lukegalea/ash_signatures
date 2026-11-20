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

  # Once the host shreds the sealed fields, every other field the hash covers is still
  # stored in plain text. Without a secret in the hash, a guess at the sealed fields
  # (an IPv4 address is 2^32 candidates) could be confirmed against it.
  describe "after the sealed fields are gone" do
    test "the true values cannot be confirmed against the stored hash" do
      event =
        record(%{
          ip_address: "198.51.100.77",
          user_agent: "Mozilla/5.0 (X11; Linux x86_64)",
          reason: nil
        })

      # What a reader still has once the scope is shredded: the plain fields and the
      # hash. The true personal values, guessed exactly, do not reproduce it.
      guess = %{
        request_id: event.request_id,
        signer_id: event.signer_id,
        type: event.type,
        route: event.route,
        sha256: event.sha256,
        ip_address: "198.51.100.77",
        user_agent: "Mozilla/5.0 (X11; Linux x86_64)",
        reason: nil,
        occurred_at: event.occurred_at
      }

      refute AshSignatures.Digest.sha256_hex(guess) == event.event_hash
      refute Hash.hash(%{event | salt: nil}) == event.event_hash
    end

    test "the secret is sealed with them, and differs per event" do
      event = record(@payload)
      other = record(@payload)

      assert is_binary(event.salt) and byte_size(event.salt) == 64
      assert Base.decode64!(event.encrypted_salt) =~ "SEALED:"
      refute event.salt == other.salt
      refute event.event_hash == other.event_hash
    end
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
    assert event.salt == nil
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
