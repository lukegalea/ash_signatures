# SPDX-FileCopyrightText: 2026 Luke Galea
# SPDX-License-Identifier: MIT

defmodule AshSignatures.Test.Fixtures do
  @moduledoc "Builds the clinic's consent-form requests for the suite. All data is synthetic."

  alias AshSignatures.Test.Domain

  def version(bytes \\ "SYNTHETIC consent form #{System.unique_integer([:positive])}"),
    do: Domain.ingest!("consent.pdf", bytes, authorize?: false)

  def subject, do: "SYNTHETIC-visit-#{System.unique_integer([:positive])}"

  @doc "A draft request on `subject` with one document and the given signer roles, in order."
  def draft(opts \\ []) do
    subject = Keyword.get_lazy(opts, :subject, &subject/0)
    source = Keyword.get_lazy(opts, :version, &version/0)
    roles = Keyword.get(opts, :roles, [:patient, :clinician])

    request =
      Domain.draft_request!(
        %{
          subject_type: Keyword.get(opts, :subject_type, "visit"),
          subject_id: subject,
          purpose: Keyword.get(opts, :purpose, :acknowledge),
          expires_at: opts[:expires_at]
        },
        authorize?: false
      )

    Domain.add_document!(%{request_id: request.id, source_version_id: source.id, position: 1},
      authorize?: false
    )

    signers =
      for {role, order} <- Enum.with_index(roles, 1) do
        Domain.add_signer!(
          %{
            request_id: request.id,
            role: role,
            order: order,
            name: "SYNTHETIC #{role}",
            email: "#{role}@example.test"
          },
          authorize?: false
        )
      end

    %{request: request, source: source, signers: signers, subject: subject}
  end

  def sent(opts \\ []) do
    fixture = draft(opts)

    request =
      Domain.send_request!(
        fixture.request,
        %{provider: Keyword.get(opts, :provider, :in_platform)},
        authorize?: false
      )

    %{fixture | request: request}
  end

  def signer(id), do: Domain.get_signer!(id, authorize?: false)

  def sign_through(signer, typed \\ %{}) do
    signer
    |> Domain.view!(%{ip_address: "192.0.2.10", user_agent: "SYNTHETIC-agent"}, authorize?: false)
    |> Domain.consent!(%{}, authorize?: false)
    |> Domain.sign!(
      Map.merge(%{ip_address: "192.0.2.10", user_agent: "SYNTHETIC-agent"}, typed),
      authorize?: false
    )
  end

  def events(request_id) do
    Domain.list_events!(
      query: [filter: [request_id: request_id], sort: [occurred_at: :asc, id: :asc]],
      authorize?: false
    )
  end
end
