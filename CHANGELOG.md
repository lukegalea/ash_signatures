<!--
SPDX-FileCopyrightText: 2026 Luke Galea
SPDX-License-Identifier: MIT
-->

# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

<!-- changelog -->

## [Unreleased]

Nothing has been released yet.

Requires Elixir 1.20 or later.

### Features:

- The request, request document, signer, signer event and completion fragments, with state machines for the request
  and the signer.
- The `AshSignatures.Provider` behaviour, and the in-platform and upload providers.
- The first signed copy completes a request; copies are deduplicated by SHA-256 on the subject; another open request
  on the subject is superseded.
- The completion record and its `record_hash`, with no personal data in it.
- A signer event's hash covers its personal fields when the host seals them (for example with `AshCloak`, which turns
  them into arguments), and an event recorded without them still records on a sealed host.
- An event recorded with a personal field gets a random `salt` that its hash covers, listed in
  `AshSignatures.payload_fields(:signer_event)` so the host seals it with the fields. Once the host erases them, the
  hash no longer confirms a guess at them (an IPv4 address, a user agent, a short reason).
- A signed copy whose bytes are an unsigned document that any request on the same subject showed is refused, not
  only one equal to the receiving request's own document.
- `AshSignatures.person_acts/0` and `AshSignatures.consequences/1` name the signer's own acts and each fragment's
  package-written actions, so a host's policies are written from the fragments' own lists.
- `AshSignatures.Stamp`: a host may put each in-platform signature into the documents as the signer signs. The stamped
  version is how the document stands (`current_version_id`, `current_sha256`): the next signer is shown it and signs
  over its hash, and the last one becomes the signed result in the completion record. A stamp that fails fails the
  signature.
- `sign` takes what the signer typed: `signed_name`, `signed_title` and `authority`. They go on the `signed` event,
  are covered by its hash and are listed in `AshSignatures.payload_fields(:signer_event)` for the host to seal. An
  event without them hashes as it did before they existed.
- The signer whose turn it becomes gets a `notified` event, and `record_delivery` records `delivered` when the host's
  mailer reports the link delivered.
- A signer act on a request it cannot read (another tenant's) is refused with an error instead of raising.
- A signed copy that completes a request signs each signer who had not acted on it (`sign_on_copy`: a `signed` event
  with route `:upload` and the copy's SHA-256) instead of withdrawing them, so the completion record of a request
  signed on paper names its signers as signed.
- A provider may say it tells no signer it is their turn (`notifies_signers?/0`, optional). `Providers.Upload` says
  so, and a paper request records no `notified` event.
