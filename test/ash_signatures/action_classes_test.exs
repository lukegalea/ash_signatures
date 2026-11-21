# SPDX-FileCopyrightText: 2026 Luke Galea
# SPDX-License-Identifier: MIT

defmodule AshSignatures.ActionClassesTest do
  @moduledoc """
  `AshSignatures.person_acts/0` and `AshSignatures.consequences/1` name actions the fragments
  declare, so a host's policies written from them cannot drift from the fragments.
  """

  use ExUnit.Case, async: true

  alias AshSignatures.Test.{Completion, Request, RequestDocument, Signer, SignerEvent}

  @resources %{
    request: Request,
    request_document: RequestDocument,
    signer: Signer,
    signer_event: SignerEvent,
    completion: Completion
  }

  defp action_names(resource),
    do: resource |> Ash.Resource.Info.actions() |> Enum.map(& &1.name)

  test "every person act is a signer action, and none is a consequence" do
    assert AshSignatures.person_acts() -- action_names(Signer) == []

    assert AshSignatures.person_acts() -- AshSignatures.consequences(:signer) ==
             AshSignatures.person_acts()
  end

  test "every consequence is an action of its fragment" do
    for {fragment, resource} <- @resources do
      assert AshSignatures.consequences(fragment) -- action_names(resource) == [],
             "#{fragment}: #{inspect(AshSignatures.consequences(fragment) -- action_names(resource))}"
    end
  end

  test "the host's own calls are not consequences" do
    refute :expire in AshSignatures.consequences(:request)
    refute :receive_signed_copy in AshSignatures.consequences(:request)
    refute :send in AshSignatures.consequences(:request)
  end
end
