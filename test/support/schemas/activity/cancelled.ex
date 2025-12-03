defmodule Polyjuice.Schemas.Activity.Cancelled do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:type, :string, default: "cancelled")
    field(:user_id, :integer)
    field(:cancelled_at, :utc_datetime)
    field(:reason, :string)
  end

  def changeset(cancelled, attrs) do
    cancelled
    |> cast(attrs, [:type, :user_id, :cancelled_at, :reason])
    |> validate_required([:user_id, :cancelled_at, :reason])
    |> validate_number(:user_id, greater_than: 0)
    |> validate_inclusion(:reason, [
      "user_request",
      "system_timeout",
      "payment_failed",
      "fraud_detected"
    ])
  end
end
