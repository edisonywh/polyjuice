defmodule Polyjuice.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes do not persist
  between tests. We also take care of migrations here.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias Polyjuice.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Polyjuice.DataCase
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Polyjuice.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Polyjuice.Repo, {:shared, self()})
    end

    run_migrations()

    :ok
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  defp run_migrations do
    migrations_path = Application.app_dir(:polyjuice, "priv/repo/migrations")
    Ecto.Migrator.run(Polyjuice.Repo, migrations_path, :up, all: true)
  end
end
