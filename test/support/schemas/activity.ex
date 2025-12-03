defmodule PolyjuiceTest.Schemas.Activity do
  use Ecto.Schema
  import Ecto.Changeset

  alias PolyjuiceTest.Schemas.Activity.{Activated, Cancelled}

  schema "activities" do
    field(:title, :string)
    field(:user_id, :integer)

    field(:event, Polyjuice,
      schemas: [
        activated: Activated,
        cancelled: Cancelled
      ]
    )

    timestamps()
  end

  def changeset(activity, attrs) do
    activity
    |> cast(attrs, [:title, :user_id, :event])
    |> validate_required([:title, :user_id, :event])
    |> validate_number(:user_id, greater_than: 0)
  end
end
