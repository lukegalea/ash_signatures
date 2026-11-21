# SPDX-FileCopyrightText: 2026 Luke Galea
# SPDX-License-Identifier: MIT

defmodule AshSignatures.Test.Domain do
  @moduledoc """
  The test host's domain: plain `Ash.Resource` modules with no base resource of their own,
  so the suite shows nothing in the package depends on a particular host. The scenario is a
  clinic asking a patient and a clinician to sign a consent form.
  """

  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource AshSignatures.Test.DocumentVersion do
      define :ingest, action: :ingest, args: [:filename, :bytes]
    end

    resource AshSignatures.Test.Request do
      define :draft_request, action: :draft
      define :get_request, action: :read, get_by: [:id]
      define :list_requests, action: :read
      define :send_request, action: :send
      define :receive_signed_copy, action: :receive_signed_copy, args: [:version_id]
      define :recall_request, action: :recall
      define :cancel_request, action: :cancel
      define :expire_request, action: :expire
    end

    resource AshSignatures.Test.RequestDocument do
      define :add_document, action: :add
      define :list_documents, action: :read
    end

    resource AshSignatures.Test.Signer do
      define :add_signer, action: :add
      define :get_signer, action: :read, get_by: [:id]
      define :list_signers, action: :read
      define :view, action: :view
      define :consent, action: :consent
      define :sign, action: :sign
      define :decline, action: :decline, args: [:reason]
      define :request_changes, action: :request_changes, args: [:reason]
      define :remind, action: :remind
      define :record_delivery, action: :record_delivery
    end

    resource AshSignatures.Test.SignerEvent do
      define :list_events, action: :read
    end

    resource AshSignatures.Test.SealedSignerEvent do
      define :record_sealed_event, action: :record
    end

    resource AshSignatures.Test.Completion do
      define :list_completions, action: :read
    end
  end
end
