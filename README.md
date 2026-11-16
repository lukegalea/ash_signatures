<!--
SPDX-FileCopyrightText: 2026 Luke Galea
SPDX-License-Identifier: MIT
-->

# AshSignatures

Signature requests for [Ash Framework](https://ash-hq.org) hosts. A request asks people to sign or acknowledge exact
document versions, in order. Each signer acts on their own row, every act is an append-only event, and the request
ends in one completion record whose hash covers what was signed, by whom, over which hashes.

The package ships Spark fragments, a state machine and a provider behaviour. The host includes the fragments on
resources built from its own base resource, and supplies the data layer, tenancy, policies, triggers, notifications,
erasure and every decision: who may send, the consent wording, how a signer is identified, reminder timing and
retention.

A signature here is a simple electronic signature: identity is whatever the host uses to let the signer reach their
row. The package has no PDF stamping, cryptographic seals, timestamps or hosted e-signature providers.

## What it ships

| Module | What it is |
|---|---|
| `AshSignatures.Request` | The request: subject, purpose, provider, documents digest, and the states `draft`, `sent`, `partially_signed`, `completed`, `returned`, `recalled`, `cancelled`, `expired`, `superseded` |
| `AshSignatures.RequestDocument` | One document version signers are shown, its position, and the signed copy's version |
| `AshSignatures.Signer` | One person, in order: `pending`, `notified`, `viewed`, then `signed`, `declined`, `changes_requested` or `withdrawn` |
| `AshSignatures.SignerEvent` | Append-only events, each with its own hash |
| `AshSignatures.Completion` | The canonical completion record and `record_hash` |
| `AshSignatures.Provider` | The asynchronous provider behaviour: `create`, `lookup`, `observe`, `fetch`, `void`, `remind` |
| `AshSignatures.Providers.InPlatform`, `AshSignatures.Providers.Upload` | Signing on the host's own surface, and signed paper copies uploaded. Neither makes a network call |

## Installation

```elixir
def deps do
  [
    {:ash_signatures, github: "lukegalea/ash_signatures"}
  ]
end
```

## Use

```elixir
defmodule MyClinic.Consent.Request do
  use MyClinic.Resource, fragments: [AshSignatures.Request]

  signature_request do
    request_document MyClinic.Consent.RequestDocument
    signer MyClinic.Consent.Signer
    signer_event MyClinic.Consent.SignerEvent
    completion MyClinic.Consent.Completion
    document_version MyClinic.Records.DocumentVersion
  end

  # Your table, tenancy and policies.
end

defmodule MyClinic.Consent.Signer do
  use MyClinic.Resource, fragments: [AshSignatures.Signer]

  signatures do
    request MyClinic.Consent.Request
  end
end
```

Draft a request, add its documents and signers, send it, and let each signer `view`, `consent` and `sign` in turn.
A signed paper copy goes to the request's `receive_signed_copy`. See [usage-rules.md](usage-rules.md) and
[what the host supplies](documentation/topics/what-the-host-supplies.md).

## Licence

MIT. See [LICENSE](LICENSE).
