# SPDX-FileCopyrightText: 2026 Luke Galea
# SPDX-License-Identifier: MIT

defmodule AshSignatures.Request do
  @moduledoc """
  A signature request: people asked to sign or acknowledge exact document versions, in order.

  Include this fragment on a resource built from the host's own base resource, and name the
  sibling resources in its `signature_request` section (`AshSignatures.Request.Dsl`):

      use MyApp.Resource, fragments: [AshSignatures.Request]

      signature_request do
        request_document MyClinic.Consent.RequestDocument
        signer MyClinic.Consent.Signer
        signer_event MyClinic.Consent.SignerEvent
        completion MyClinic.Consent.Completion
        document_version MyClinic.Records.DocumentVersion
      end

  ## Attributes

    * `subject_type`, `subject_id`: the record the request is about, as the host names it.
      The package never reads or changes the subject.
    * `purpose`: `:execute` (signing makes something take effect) or `:acknowledge`.
    * `routing`: `:sequential`, the only routing: signers act in `order`, one at a time.
    * `provider`, `provider_ref`: the provider key copied when the request is sent, and the
      provider's reference for it.
    * `documents_digest`: SHA-256 over the canonical JSON of the documents' SHA-256s in
      position order and the signers' roles in order, fixed when the request is sent.
    * `status`: `draft`, `sent`, `partially_signed`, `completed`, `returned` (a signer
      declined or asked for changes), `recalled`, `cancelled`, `expired` or `superseded`
      (another request on the same subject completed first).

  ## Actions

    * `draft` (create): the subject, purpose and optional `expires_at`. Documents and signers
      are added to a draft with the `add` actions of their resources.
    * `send` (update): checks the request has documents and signers numbered from 1, fixes
      `documents_digest`, asks the provider for an existing reference (`lookup`) and creates
      one only when there is none, and notifies the first signer (unless the provider tells
      no one, as paper does: `notifies_signers?/0`).
    * `receive_signed_copy` (update): a signed copy, as a document version, arrived for one
      of the request's documents. See "Signed copies" below.
    * `recall`, `cancel`, `expire` (update): end a request that has not completed. Signers who
      have not acted are withdrawn, and the provider is told (`void`).
    * `advance`, `return`, `supersede` (update): the consequences of a signer's act or of
      another request completing. The package calls them; a host does not need to.

  ## Signed copies

  The first signed copy completes the request. A copy is a document version; its SHA-256 is
  read from the version. A copy whose bytes are an unsigned document, this request's or one
  that another request on the same subject showed, is refused. So is a version the host
  stamped while a request on the subject was signed in the platform (`AshSignatures.Stamp`)
  that carries only some of the signatures: one a later signer was shown, or how a document
  stands on a request that has not completed. A copy whose SHA-256 was already received for
  the same subject, on any request, or that is the stamped result of a request completed in
  the platform, is recognised and changes nothing. Any other copy is recorded as a `signed` event with route `:upload`; on an
  open request it becomes that document's result, and once every document has a result the
  request completes. A copy that arrives after the request ended is recorded and completes
  nothing.

  ## Completion

  When the last signer signs, or the last document receives its signed copy, the request is
  `completed`: signers who have not acted are withdrawn (or, when a signed copy completed it,
  signed on that copy: `sign_on_copy`), one `AshSignatures.Completion` row
  is written, and every other open request on the same subject is `superseded`. The host
  reacts to `completed` and `returned` with its own actions; the package never changes the
  subject.

  Writes that follow from an act (an event, the request moving on, the completion) run with
  the acting actor and tenant and `authorize?: false`: the host's policies on the act decide.
  """

  use Spark.Dsl.Fragment,
    of: Ash.Resource,
    extensions: [AshStateMachine, AshSignatures.Request.Dsl]

  state_machine do
    state_attribute :status
    initial_states [:draft]
    default_initial_state :draft

    transitions do
      transition :send, from: :draft, to: :sent
      transition :advance, from: [:sent, :partially_signed], to: [:partially_signed, :completed]
      transition :receive_signed_copy, from: [:sent, :partially_signed], to: :completed
      transition :return, from: [:sent, :partially_signed], to: :returned
      transition :recall, from: [:sent, :partially_signed], to: :recalled
      transition :cancel, from: [:draft, :sent, :partially_signed], to: :cancelled
      transition :expire, from: [:sent, :partially_signed], to: :expired
      transition :supersede, from: [:draft, :sent, :partially_signed], to: :superseded
    end
  end

  actions do
    defaults [:read]

    create :draft do
      accept [:subject_type, :subject_id, :purpose, :expires_at]
    end

    update :send do
      require_atomic? false

      argument :provider, :atom do
        allow_nil? false
        default :in_platform
      end

      change AshSignatures.Request.Changes.Send
    end

    update :advance do
      require_atomic? false
      change AshSignatures.Request.Changes.Advance
    end

    update :receive_signed_copy do
      require_atomic? false

      argument :version_id, :uuid do
        allow_nil? false
        description "The document version holding the signed copy."
      end

      argument :request_document_id, :uuid do
        description "Which of the request's documents it is a copy of. Needed only when there is more than one."
      end

      argument :ip_address, :string, sensitive?: true
      argument :user_agent, :string, sensitive?: true

      change AshSignatures.Request.Changes.ReceiveSignedCopy
    end

    update :return do
      require_atomic? false
      change {AshSignatures.Request.Changes.End, to: :returned}
    end

    update :recall do
      require_atomic? false
      change {AshSignatures.Request.Changes.End, to: :recalled}
    end

    update :cancel do
      require_atomic? false
      change {AshSignatures.Request.Changes.End, to: :cancelled}
    end

    update :expire do
      require_atomic? false
      change {AshSignatures.Request.Changes.End, to: :expired}
    end

    update :supersede do
      require_atomic? false
      change {AshSignatures.Request.Changes.End, to: :superseded}
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :subject_type, :string do
      allow_nil? false
      public? true
      constraints min_length: 1
    end

    attribute :subject_id, :string do
      allow_nil? false
      public? true
      constraints min_length: 1
    end

    attribute :purpose, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:execute, :acknowledge]
    end

    attribute :routing, :atom do
      allow_nil? false
      public? true
      default :sequential
      constraints one_of: [:sequential]
    end

    attribute :provider, :atom, public?: true
    attribute :provider_ref, :string, public?: true
    attribute :documents_digest, :string, public?: true
    attribute :expires_at, :utc_datetime_usec, public?: true
    attribute :sent_at, :utc_datetime_usec, public?: true
    attribute :ended_at, :utc_datetime_usec, public?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end
