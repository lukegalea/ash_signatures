# SPDX-FileCopyrightText: 2026 Luke Galea
# SPDX-License-Identifier: MIT

defmodule AshSignatures.Stamp do
  @moduledoc """
  Puts a signature into a document. Optional: a host names a module in
  `signature_request` when an in-platform signature should change the document itself (a
  signature drawn into its field, say); a host that names none keeps the documents as they
  were sent.

  The package calls `stamp/2` once per document of the request, right after a signer
  signs, in the same transaction. The host stores the stamped bytes as a new immutable
  document version and returns it. That version is the document **as it now stands**
  (`current_version_id`, `current_sha256` on the request document): the next signer is shown
  it, so the hash they sign over (`shown_sha256`) is the hash of the document with every
  signature before theirs. When the last signer signs, the last stamped version becomes the
  document's signed result (`result_version_id`, `result_sha256`), which the completion
  record holds.

  Return `:unchanged` to leave a document as it stands (one with no field for this signer).
  An `{:error, reason}` fails the signature, so nothing is signed over a document the host
  could not stamp.

  How the signature looks, which field it goes in and how the bytes change are the host's.
  A host that must keep the earlier bytes (so the document the first signer was shown is a
  prefix of the signed one) appends the stamp as an incremental update.
  """

  @typedoc """
  What a stamp is given:

    * `document`: the request document row;
    * `version_id`: the version to stamp, the document as it stands (the source version
      before any stamp);
    * `signer`: the signer row, just signed;
    * `signature`: what the signer typed and when: `signed_name`, `signed_title`,
      `authority` (any may be `nil`) and `signed_at`;
    * `request`, `actor`, `tenant`: as `t:AshSignatures.Provider.context/0`.
  """
  @type input :: %{
          document: Ash.Resource.record(),
          version_id: term(),
          signer: Ash.Resource.record(),
          signature: %{
            signed_name: String.t() | nil,
            signed_title: String.t() | nil,
            authority: String.t() | nil,
            signed_at: DateTime.t()
          },
          request: Ash.Resource.record(),
          actor: term(),
          tenant: term()
        }

  @callback stamp(input()) ::
              {:ok, %{version_id: term(), sha256: String.t()}} | :unchanged | {:error, term()}
end
