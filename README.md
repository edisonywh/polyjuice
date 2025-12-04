# 🧬 Polyjuice

![logo](./polyjuice.png)

A custom type that maps polymorphic data to different Ecto schemas based on a type field.

`Polyjuice` allows you to store different types of data in a single field, where each
type is validated and cast to its own embedded schema.

## Example

```elixir
defmodule Activity do
  use Ecto.Schema
  import Ecto.Changeset
  
  schema "activities" do
    field :title, :string
    field :event, Polyjuice, schemas: %{
      activated: ActivatedEvent,
      cancelled: CancelledEvent
    }
  end

  def changeset(activity, attrs) do
    activity
    |> cast(attrs, [:title])
    |> Polyjuice.cast_embed(:event)
    |> validate_required([:title, :event])
  end
end

defmodule ActivatedEvent do
  use Ecto.Schema
  import Ecto.Changeset
  
  @primary_key false
  embedded_schema do
    field(:type, :string, default: "activated")
    field(:user_id, :integer)
    field(:activated_at, :utc_datetime)
  end
  
  def changeset(activated, attrs) do
    activated
    |> cast(attrs, [:type, :user_id])
    |> validate_required([:user_id, :activated_at])
    |> validate_number(:user_id, greater_than: 0)
  end
end

defmodule CancelledEvent do
  use Ecto.Schema
  import Ecto.Changeset
  
  @primary_key false
  embedded_schema do
    field(:type, :string, default: "cancelled")
    field(:user_id, :integer)
    field(:reason, :string)
  end

  def changeset(cancelled, attrs) do
    cancelled
    |> cast(attrs, [:type, :user_id, :reason])
    |> validate_required([:user_id, :reason])
    |> validate_number(:user_id, greater_than: 0)
    |> validate_inclusion(:reason, [
      "user_request",
      "system_timeout",
      "payment_failed",
      "fraud_detected"
    ])
  end
end
```

## Usage
```elixir
%Activity{
  title: "User Action",
  event: %ActivatedEvent{
    type: "activated",
    user_id: 123,
    activated_at: DateTime.utc_now()
  }
}
|> Repo.insert()
```

## Caveat(s)
1) Map-based input & `Ecto.Changeset.cast/3`

Polyjuice does not currently support map/json-based input, only structs are allowed, thus the following won't work:

```elixir
%Activity{}
|> Activity.changeset(%{
  title: "User Action",
  event: %{
    "type" => "activated",
    "user_id" => 123,
    "activated_at" => DateTime.utc_now()
  }
})
|> Repo.insert()
```

2) Schema evolution

Be very careful about reading & writing back into database, currently this can be a lossy conversion.

For example, if your event has an extra field, when you read it back out, it'll not contain that field, and when you try to update this, it'll lose the extra field.

We are currently using it as an append-only database table with polymorphic embed, but we're open to ideas to make it more robust.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `polyjuice` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:polyjuice, "~> 0.1.0"}
  ]
end
```
