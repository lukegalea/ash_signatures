<!--
SPDX-FileCopyrightText: 2026 Luke Galea
SPDX-License-Identifier: MIT
-->

# Rules for working with AshSignatures

## Status

Built: the request, request document, signer, signer event and completion fragments; their state machines; the
provider behaviour with the in-platform and upload providers; first-copy completion with SHA-256 deduplication; the
completion record. Not built, and not planned until a second use needs it: a signer principal for people without an
account, PDF stamping, seals, timestamps, hosted providers.

## Understanding AshSignatures

- **The package declares** five Spark fragments with attributes, actions, changes and state machines, a provider
  behaviour and two providers.
- **The host supplies** the base resource and data layer, tenancy, ownership, policies, triggers (expiry, reminders),
  notifications, audit, erasure, and the surface signers use.

## Rules

1. Include each fragment on a resource built from your own base resource. Do not copy its attributes or actions.
2. Name the sibling resources in the request's `signature_request` section, and the request in the `signatures`
   section of the request document and signer resources.
3. The document version resource must be immutable and have a `sha256` attribute (lowercase hex of the bytes).
4. Write policies on your own resources. The fragments contain none. Signing is a person's act: never let an
   automation principal reach a signer's `sign` action.
5. Never add an update or destroy action to the signer event or completion resources. They are append-only.
6. Seal the fields in `AshSignatures.payload_fields/1` under your erasure scope. Everything else (hashes, roles,
   order, event types, times, the completion record) is kept.
7. React to a request reaching `completed` or `returned` with your own actions. The package never changes the
   subject.
8. Run `expire` from your own trigger when `expires_at` passes. The package refuses signer acts after it, but does not
   schedule anything.
9. A new provider implements `AshSignatures.Provider` and is added to `providers`. `send` calls `lookup` before
   `create`, so a provider must answer `lookup` with the reference of a request it already holds.
10. Consequences of an act (an event, the request moving on, the completion) are written with the acting actor and
    tenant and `authorize?: false`. Your policies decide who may act.
