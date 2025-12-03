defmodule Polyjuice do
  @moduledoc """
  A custom type that maps polymorphic data to different Ecto schemas based on a type field.

  `Polyjuice` allows you to store different types of data in a single field, where each
  type is validated and cast to its own embedded schema. It can be used in your schemas
  as follows:

      field :event, Polyjuice, schemas: %{
        activated: MyApp.ActivatedEvent,
        cancelled: MyApp.CancelledEvent
      }

  The type is determined by a `type` field in the data, which can be either a string
  or atom key. The data is then cast to the appropriate schema based on this mapping.

  ## Example

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
          |> cast(attrs, [:title, :event])
          |> validate_required([:title, :event])
        end
      end

  ## Usage

      # With map data (e.g., from JSON/forms)
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

      # With struct data
      %Activity{
        title: "User Action",
        event: %ActivatedEvent{
          type: "activated",
          user_id: 123,
          activated_at: DateTime.utc_now()
        }
      }
      |> Repo.insert()
  """

  use Ecto.ParameterizedType

  @impl true
  def type(_params), do: :map

  @impl true
  def init(opts) do
    schemas_option = opts[:schemas] || %{}

    schemas =
      case schemas_option do
        schemas when is_map(schemas) ->
          schemas

        schemas when is_list(schemas) ->
          Enum.into(schemas, %{})

        _ ->
          %{}
      end

    unless is_map(schemas) and map_size(schemas) > 0 do
      raise ArgumentError, """
      Polyjuice types must have a schemas option specified as a map or keyword list from atoms to schema modules.

      For example:

          field :my_field, Polyjuice, schemas: [
            type1: MyApp.Schema1,
            type2: MyApp.Schema2
          ]
      """
    end

    # Validate all values are modules
    Enum.each(schemas, fn {key, module} ->
      unless is_atom(key) and is_atom(module) do
        raise ArgumentError,
              "schemas must map atoms to modules, got #{inspect(key)} => #{inspect(module)}"
      end
    end)

    # Create lookup maps for efficient casting/loading/dumping
    type_to_module = schemas
    string_to_module = for {type, module} <- schemas, into: %{}, do: {to_string(type), module}
    module_to_type = for {type, module} <- schemas, into: %{}, do: {module, type}

    %{
      type_to_module: type_to_module,
      string_to_module: string_to_module,
      module_to_type: module_to_type,
      schemas: schemas
    }
  end

  @impl true
  def cast(nil, _params), do: {:ok, nil}

  def cast(data, params) when is_struct(data) do
    # If it's already a struct from one of our schemas, accept it
    module = data.__struct__

    case params.module_to_type do
      %{^module => _type} ->
        {:ok, data}

      _ ->
        {:error, [type: {"unknown struct type", [validation: :polyjuice_cast]}]}
    end
  end

  def cast(data, params) when is_map(data) do
    case get_schema_module(data, params) do
      nil ->
        {:error, [type: {"no type field found", [validation: :polyjuice_cast]}]}

      {:unknown, type_value} ->
        {:error, [type: {"unknown type #{inspect(type_value)}", [validation: :polyjuice_cast]}]}

      {type, module} ->
        # Ensure type field is present and correctly formatted
        data_with_type = ensure_type_field(data, type)

        # Create changeset and validate
        changeset = module.changeset(struct(module), data_with_type)

        if changeset.valid? do
          {:ok, Ecto.Changeset.apply_changes(changeset)}
        else
          {:error, changeset.errors}
        end
    end
  end

  def cast(_data, _params), do: {:error, [type: {"invalid data", [validation: :polyjuice_cast]}]}

  @impl true
  def load(nil, _loader, _params), do: {:ok, nil}

  def load(data, _loader, params) when is_map(data) do
    case get_schema_module(data, params) do
      {_type, module} ->
        # Convert string keys to atom keys for struct creation
        atom_data =
          for {key, val} <- data, into: %{} do
            atom_key = if is_binary(key), do: String.to_existing_atom(key), else: key
            {atom_key, val}
          end

        {:ok, struct(module, atom_data)}

      _ ->
        # If we can't determine the type, it's a data integrity issue
        :error
    end
  rescue
    ArgumentError ->
      # String.to_existing_atom failed - unknown type in database
      :error
  end

  def load(data, _loader, _params), do: {:ok, data}

  @impl true
  def dump(nil, _dumper, _params), do: {:ok, nil}

  def dump(data, _dumper, _params) when is_struct(data) do
    {:ok, Map.from_struct(data)}
  end

  # def dump(data, _dumper, _params) when is_map(data) do
  #   # technically if i recast it back to polyjuice struct
  #   {:ok, data}
  # end
  #

  def dump(_data, _dumper, _params), do: :error

  @impl true
  def equal?(a, b, _params), do: a == b

  @impl true
  def embed_as(_format, _params), do: :self

  # Private helper functions

  defp get_schema_module(data, params) do
    type_value = data["type"] || data[:type]

    try do
      case type_value do
        nil ->
          nil

        type when is_binary(type) ->
          case params.string_to_module do
            %{^type => module} -> {String.to_existing_atom(type), module}
            _ -> {:unknown, type}
          end

        type when is_atom(type) ->
          case params.type_to_module do
            %{^type => module} -> {type, module}
            _ -> {:unknown, type}
          end

        _ ->
          {:unknown, type_value}
      end
    rescue
      ArgumentError ->
        # String.to_existing_atom failed
        {:unknown, type_value}
    end
  end

  defp ensure_type_field(data, type) do
    cond do
      # Data has all string keys - use string type key
      Enum.all?(Map.keys(data), &is_binary/1) ->
        Map.put(data, "type", to_string(type))

      # Data has mixed or all atom keys - use atom type key
      true ->
        Map.put(data, :type, type)
    end
  end
end
