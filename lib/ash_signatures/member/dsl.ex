# SPDX-FileCopyrightText: 2026 Luke Galea
# SPDX-License-Identifier: MIT

defmodule AshSignatures.Member.Dsl do
  @section %Spark.Dsl.Section{
    name: :signatures,
    describe: """
    The request resource a request document or signer belongs to. The
    `AshSignatures.RequestDocument` and `AshSignatures.Signer` fragments bring this extension.
    """,
    examples: [
      """
      signatures do
        request MyClinic.Consent.Request
      end
      """
    ],
    schema: [
      request: [
        type: :atom,
        required: true,
        doc: "The host's resource that includes `AshSignatures.Request`."
      ]
    ]
  }

  @moduledoc """
  The `signatures` section on a host resource that includes `AshSignatures.RequestDocument`
  or `AshSignatures.Signer`.

  #{Spark.Dsl.Extension.doc_index([@section])}

  #{Spark.Dsl.Extension.doc([@section])}
  """

  use Spark.Dsl.Extension, sections: [@section]

  @doc "The request resource named in the `signatures` section."
  @spec request(Ash.Resource.t()) :: Ash.Resource.t()
  def request(resource), do: Spark.Dsl.Extension.get_opt(resource, [:signatures], :request)
end
