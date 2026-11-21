# SPDX-FileCopyrightText: 2026 Luke Galea
# SPDX-License-Identifier: MIT

defmodule AshSignatures.Request.Dsl do
  @section %Spark.Dsl.Section{
    name: :signature_request,
    describe: """
    What the host supplies to the `AshSignatures.Request` fragment: the resources a request's
    documents, signers, events and completion live in, the resource its document versions are
    read from, and its providers.
    """,
    examples: [
      """
      signature_request do
        request_document MyClinic.Consent.RequestDocument
        signer MyClinic.Consent.Signer
        signer_event MyClinic.Consent.SignerEvent
        completion MyClinic.Consent.Completion
        document_version MyClinic.Records.DocumentVersion
      end
      """
    ],
    schema: [
      request_document: [
        type: :atom,
        required: true,
        doc: "The host's resource that includes `AshSignatures.RequestDocument`."
      ],
      signer: [
        type: :atom,
        required: true,
        doc: "The host's resource that includes `AshSignatures.Signer`."
      ],
      signer_event: [
        type: :atom,
        required: true,
        doc: "The host's resource that includes `AshSignatures.SignerEvent`."
      ],
      completion: [
        type: :atom,
        required: true,
        doc: "The host's resource that includes `AshSignatures.Completion`."
      ],
      document_version: [
        type: :atom,
        required: true,
        doc: """
        The host's immutable document version resource. It must have a `sha256` attribute holding
        the lowercase hex SHA-256 of the version's bytes, and a primary read action.
        """
      ],
      providers: [
        type: :keyword_list,
        default: [
          in_platform: AshSignatures.Providers.InPlatform,
          upload: AshSignatures.Providers.Upload
        ],
        doc: """
        The providers a request may be sent through, by key. Each implements
        `AshSignatures.Provider`. The key is copied onto the request when it is sent.
        """
      ],
      chain_head: [
        type: {:behaviour, AshSignatures.ChainHead},
        doc: """
        Reads the head of the host's audit chain for the request's tenant, which the completion
        record includes. Without it the record's `chain_head` is `nil`.
        """
      ],
      stamp: [
        type: {:behaviour, AshSignatures.Stamp},
        doc: """
        Puts each in-platform signature into the documents as the signer signs. Without it the
        documents stay as they were sent. See `AshSignatures.Stamp`.
        """
      ]
    ]
  }

  @moduledoc """
  The `signature_request` section a host fills on a resource that includes the
  `AshSignatures.Request` fragment. The fragment brings this extension with it.

  #{Spark.Dsl.Extension.doc_index([@section])}

  #{Spark.Dsl.Extension.doc([@section])}
  """

  use Spark.Dsl.Extension,
    sections: [@section],
    verifiers: [AshSignatures.Request.Verifiers.VerifyHost]
end
