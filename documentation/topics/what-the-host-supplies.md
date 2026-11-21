<!--
SPDX-FileCopyrightText: 2026 Luke Galea
SPDX-License-Identifier: MIT
-->

# What the host supplies

The fragments declare attributes, actions, changes and state machines. Everything that is a decision belongs to the
host.

| The host supplies | Where |
|---|---|
| Base resource, data layer, table | each resource's `use` and data layer block |
| The sibling resources | `signature_request` on the request; `signatures` on the request document and signer |
| Immutable document versions with `sha256` | the `document_version` resource |
| Tenancy | the host's base resource; the package passes the tenant through every write |
| Policies: who may send, recall, cancel, remind, and which person a signer row is | the host's resources |
| How a signer is identified (an account, an email link) | the host's own attributes on the signer, and its policies |
| Consent and authority wording, branding, locale | the host's signing surface |
| Notifications (it is your turn, a reminder, signed by everyone) | a notifier on the host's resources |
| Expiry and reminder timing | the host's triggers calling `expire` and `remind` |
| What happens to the subject on `completed` or `returned` | the host's own actions |
| Erasure | the host seals `AshSignatures.payload_fields/1` under its scope (with `AshCloak`, for example); the event hash still covers them, and the event's `salt`, sealed with them, keeps the hash from confirming a guess at them once they are erased |
| Retention of document versions | the host's retention rules |
| Audit | the host's base resource |
| The audit chain head written into each completion | an `AshSignatures.ChainHead` named in `signature_request` |
| How a signature is put into a document, if at all | an `AshSignatures.Stamp` named in `signature_request` |
| Which typed fields (name, title, authority) a signature needs | a validation on the host's signer resource |
| A signer's link delivery | the host's mailer calls the signer's `record_delivery` |

## Writes the package makes for an act

An act a host authorizes has consequences the package writes itself, with the acting actor and tenant and
`authorize?: false`:

- a signer act records its event, and a signer whose turn it becomes gets a `notified` event;
- a signature is stamped into each document when the host supplies a stamp, and the stamped version becomes how the
  document stands;
- a signature moves the request to `partially_signed` (notifying the next signer) or `completed`;
- a decline or change request moves the request to `returned`;
- a request that ends withdraws the signers who had not acted, each with an event;
- a completion makes each document's last stamped version its signed result, writes the completion record and supersedes the subject's other open requests.

## Field names

The fragments name their foreign keys `request_id`, `signer_id`, `source_version_id` and `result_version_id` as
plain attributes. A host that wants relationships declares them with `define_attribute? false`.
