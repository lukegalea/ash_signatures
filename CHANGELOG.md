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
