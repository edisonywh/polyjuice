defmodule Polyjuice.Schemas.Activity.OtherSchema do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:name, :string)
    field(:value, :integer)
  end

  def changeset(other, attrs) do
    other
    |> cast(attrs, [:name, :value])
    |> validate_required([:name])
  end
end
