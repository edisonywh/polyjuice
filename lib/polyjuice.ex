defmodule Polyjuice do
  @moduledoc """
  A custom type that maps polymorphic data to different Ecto schemas based on a type field.

  `Polyjuice` allows you to store different types of data in a single field, where each
  type is validated and cast to its own embedded schema.

  See README.md for more.
  """

  use Ecto.ParameterizedType

  @impl true
  def type(_params), do: :map

  @impl true
  def init(opts) do
    schemas = opts[:schemas] |> Enum.into(%{})

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

  # (todo) Ecto.Changeset.cast/3 doesn't work
  # def cast(data, params) when is_struct(data) do
  #   module = data.__struct__

  #   case params.module_to_type do
  #     %{^module => _type} ->
  #       {:ok, data}

  #     _ ->
  #       {:error, [type: {"unknown struct type", [validation: :polyjuice_cast]}]}
  #   end
  # end

  # def cast(data, params) when is_map(data) do
  #   case get_schema_module(data, params) do
  #     nil ->
  #       {:error, [type: {"no type field found", [validation: :polyjuice_cast]}]}

  #     {:unknown, type_value} ->
  #       {:error, [type: {"unknown type #{inspect(type_value)}", [validation: :polyjuice_cast]}]}

  #     {type, module} ->
  #       data_with_type = ensure_type_field(data, type)
  #       changeset = module.changeset(struct(module), data_with_type)

  #       if changeset.valid? do
  #         {:ok, Ecto.Changeset.apply_changes(changeset)}
  #       else
  #         {:error, changeset.errors}
  #       end
  #   end
  # end

  def cast(_data, _params),
    do:
      {:error,
       [
         type:
           {"invalid data, use Polyjuice.cast_embed/2",
            [
              validation: :polyjuice_cast
            ]}
       ]}

  @impl true
  def load(data, _loader, params) when is_map(data) do
    case get_schema_module(data, params) do
      {_type, module} ->
        atom_data =
          for {key, val} <- data, into: %{} do
            atom_key = if is_binary(key), do: String.to_existing_atom(key), else: key
            {atom_key, val}
          end

        {:ok, struct(module, atom_data)}

      _ ->
        {:ok, data}
    end
  rescue
    _ -> {:ok, data}
  end

  def load(data, _loader, _params), do: {:ok, data}

  @impl true
  def dump(nil, _dumper, _params), do: {:ok, nil}

  def dump(data, _dumper, _params) when is_struct(data) do
    {:ok, Map.from_struct(data)}
  end

  def dump(data, _dumper, _params) when is_map(data) do
    {:ok, data}
  end

  def dump(_data, _dumper, _params), do: :error

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

  defp ensure_type_field(data, type), do: Map.put(data, "type", to_string(type))

  @doc """
  Validates and casts a Polyjuice field in a changeset.

  This function should be called in your schema's changeset function to properly
  validate embedded Polyjuice data. It will cast the data to the appropriate
  embedded schema and run its changeset validation.

  The schemas configuration is automatically extracted from the field definition,
  so you don't need to pass it manually.

  ## Usage

      def changeset(activity, attrs) do
        activity
        |> cast(attrs, [:title, :user_id])
        |> Polyjuice.cast_embed(:event)
        |> validate_required([:title, :user_id, :event])
      end

  ## Parameters

    * `changeset` - The Ecto changeset
    * `field` - The field name (atom) that contains Polyjuice data

  ## Returns

  The updated changeset with validation errors if any are found.
  """
  def cast_embed(changeset, field) do
    import Ecto.Changeset

    # Extract schemas from field definition
    {:parameterized, {Polyjuice, params}} = changeset.data.__struct__.__schema__(:type, field)
    data = changeset.params[to_string(field)] || changeset.params[field]

    case data do
      nil ->
        changeset

      data when is_struct(data) ->
        validate_struct(changeset, field, data, params)

      data when is_map(data) ->
        validate_map(changeset, field, data, params)

      _ ->
        add_error(changeset, field, "invalid data format")
    end
  end

  defp validate_struct(changeset, field, data, params) do
    import Ecto.Changeset

    module = data.__struct__
    allowed_modules = Map.values(params.schemas)

    if module in allowed_modules do
      data_as_map = Map.from_struct(data)
      embedded_changeset = module.changeset(struct(module), data_as_map)

      if embedded_changeset.valid? do
        put_change(changeset, field, data)
      else
        add_embedded_errors(changeset, field, embedded_changeset.errors)
      end
    else
      add_error(changeset, field, "invalid polyjuice schema type #{inspect(module)}")
    end
  end

  defp validate_map(changeset, field, data, params) do
    import Ecto.Changeset

    case get_schema_module(data, params) do
      nil ->
        add_error(changeset, field, "no type field found")

      {:unknown, type_value} ->
        add_error(changeset, field, "unknown type #{inspect(type_value)}")

      {type, module} ->
        data_with_type = ensure_type_field(data, type)
        embedded_changeset = module.changeset(struct(module), data_with_type)

        if embedded_changeset.valid? do
          validated_struct = Ecto.Changeset.apply_changes(embedded_changeset)
          put_change(changeset, field, validated_struct)
        else
          add_embedded_errors(changeset, field, embedded_changeset.errors)
        end
    end
  end

  defp add_embedded_errors(changeset, field, errors) do
    import Ecto.Changeset

    Enum.reduce(errors, changeset, fn {key, {message, _opts}}, acc ->
      add_error(acc, field, "#{key} #{message}")
    end)
  end
end
