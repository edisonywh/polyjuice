defmodule Polyjuice.Schemas.Activity.Activated do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:type, :string, default: "activated")
    field(:user_id, :integer)
    field(:activated_at, :utc_datetime)
    field(:activation_code, :string)
  end

  def changeset(activated, attrs) do
    activated
    |> cast(attrs, [:type, :user_id, :activated_at, :activation_code])
    |> validate_required([:user_id, :activated_at])
    |> validate_number(:user_id, greater_than: 0)
  end
end
