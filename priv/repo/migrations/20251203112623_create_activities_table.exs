defmodule Polyjuice.Repo.Migrations.CreateActivitiesTable do
  use Ecto.Migration

  def change do
    create table(:activities) do
      add(:title, :string, null: false)
      add(:user_id, :integer, null: false)
      add(:event, :map)

      timestamps()
    end

    create(index(:activities, [:user_id]))
    create(index(:activities, [:title]))
  end
end
