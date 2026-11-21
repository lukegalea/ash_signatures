<!--
SPDX-FileCopyrightText: 2026 Luke Galea
SPDX-License-Identifier: MIT
-->

# Rules for working with AshSignatures

## Status

Built: the request, request document, signer, signer event and completion fragments; their state machines; the
provider behaviour with the in-platform and upload providers; first-copy completion with SHA-256 deduplication; the
completion record; the stamp seam a host uses to put each in-platform signature into the documents; what a signer
types when signing; the link events (`notified`, and `delivered` when the host reports it). Not built, and not planned
until a second use needs it: a signer principal for people without an account, PDF stamping itself (the host's
stamp does it), seals, timestamps, hosted providers.

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
   automation principal reach a signer's `sign` action. `AshSignatures.person_acts/0` names the signer's own acts
   (`view`, `consent`, `sign`, `decline`, `request_changes`); admit only the person a signer row names to them.
5. Never add an update or destroy action to the signer event or completion resources. They are append-only.
6. Seal the fields in `AshSignatures.payload_fields/1` under your erasure scope. Everything else (hashes, roles,
   order, event types, times, the completion record) is kept. Cloaking them with `AshCloak` works, and so does a
   seal change of your own that drops each argument once it is encrypted: the event hash reads them as the event
   is recorded, before your changes run, so it still covers them. The list includes the signer event's `salt`: seal
   it with the fields, or the hash stays a way to check a guess at them after they are erased.
7. React to a request reaching `completed` or `returned` with your own actions. The package never changes the
   subject.
8. Run `expire` from your own trigger when `expires_at` passes. The package refuses signer acts after it, but does not
   schedule anything.
9. A new provider implements `AshSignatures.Provider` and is added to `providers`. `send` calls `lookup` before
   `create`, so a provider must answer `lookup` with the reference of a request it already holds.
10. To change the documents as signers sign (a signature drawn into its field), name an `AshSignatures.Stamp` in
    `signature_request`. It must store each stamped document as a new immutable version and return it; the next
    signer is shown it, and the last one is the signed result in the completion record. Without one, the documents
    stay as they were sent.
11. Record a signer's link delivery with `record_delivery` when your mailer reports it. The package records
    `notified` itself when it becomes a signer's turn: that the turn came, not that anything was sent. A provider
    that tells no one (`notifies_signers?/0` false, as `Providers.Upload`) records no `notified` at all.
12. What a signer types (`signed_name`, `signed_title`, `authority`) is optional in the package. Require what your
    signing needs with a validation on your own resource.
13. Consequences of an act (an event, the request moving on, the completion) are written with the acting actor and
    tenant and `authorize?: false`. Your policies decide who may act. `AshSignatures.consequences/1` names those
    actions for each fragment: grant them to nobody, so no one can cause the bookkeeping without the act.
14. A signed copy that completes a request signs each signer who had not acted on it (`sign_on_copy`, a `signed`
    event with route `:upload` and the copy's SHA-256), instead of withdrawing them. Grant `sign_on_copy` to nobody,
    as every other consequence.
