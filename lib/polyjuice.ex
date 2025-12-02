defmodule Polyjuice do
  use Ecto.ParameterizedType

  @impl Ecto.ParameterizedType
  def init(opts), do: Enum.into(opts, %{})

  @impl Ecto.ParameterizedType
  def type(_params), do: :map

  defp put_type(data, type) do
    if Enum.all?(Map.keys(data), &is_binary/1) do
      Map.put(data, to_string(type), type)
    else
      Map.put(data, :type, type)
    end
  end

  defp do_cast({type, module}, data) do
    changeset = module.changeset(struct(module), put_type(data, type))

    if changeset.valid? do
      {:ok, Ecto.Changeset.apply_changes(changeset)}
    else
      {:error, changeset.errors}
    end
  end

  @impl Ecto.ParameterizedType
  def cast(data, values) when is_struct(data) do
    mapping = get_mapping(values, data.__struct__)
    do_cast(mapping, Map.from_struct(data))
  end

  @impl Ecto.ParameterizedType
  def cast(data, values) do
    mapping = get_mapping(values, data)
    do_cast(mapping, data)
  end

  @impl Ecto.ParameterizedType
  defdelegate dump(value, fun, embed), to: Ecto.Embedded

  @impl Ecto.ParameterizedType
  defdelegate load(value, fun, opts), to: Ecto.Embedded

  defp get_mapping(values, %{type: type}) when is_binary(type) do
    {String.to_existing_atom(type), get_in(values, [:schemas, type])}
  end

  defp get_mapping(values, %{type: type}) when is_atom(type) do
    {type, get_in(values, [:schemas, type])}
  end

  defp get_mapping(values, %{"type" => type}) when is_binary(type) do
    type = String.to_existing_atom(type)

    {type, get_in(values, [:schemas, type])}
  end

  defp get_mapping(values, %{"type" => type}) when is_atom(type) do
    {type, get_in(values, [:schemas, type])}
  end

  defp get_mapping(values, mod) when is_atom(mod) do
    type =
      Enum.find_value(values.schemas, fn {k, v} ->
        if v == mod, do: k
      end)

    {type, mod}
  end
end
