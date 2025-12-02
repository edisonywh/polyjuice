defmodule Polyjuice do
  use Ecto.ParameterizedType

  # TODO: I need to take in both atom and string type
  # @discriminator "type"
  @discriminator :type

  @impl Ecto.ParameterizedType
  def init(opts), do: {:ok, Enum.into(opts, %{})}

  @impl Ecto.ParameterizedType
  def type(_params), do: :map

  @impl Ecto.ParameterizedType
  def dump(%module{} = struct, _dumper, params) do
    case Enum.find(params.schemas, fn {_k, v} -> v == module end) do
      {type_atom, _module} ->
        map = Map.from_struct(struct)
        {:ok, Map.put(map, @discriminator, to_string(type_atom))}

      nil ->
        {:error, "Struct module #{inspect(module)} is not allowed in Polyjuice."}
    end
  end

  def dump(nil, _dumper, _params), do: {:ok, nil}
  def dump(_other, _dumper, _params), do: :error

  @impl Ecto.ParameterizedType
  def load(data, _loader, params) when is_map(data) do
    with type_string <- Map.get(data, @discriminator),
         type_atom <- String.to_existing_atom(type_string),
         module when is_atom(module) <- Keyword.get(params.schemas, type_atom) do
      data_without_type = Map.delete(data, @discriminator)
      {:ok, struct!(module, data_without_type)}
    else
      _ ->
        {:error,
         "Polyjuice could not load data. Missing or unconfigured discriminator key #{@discriminator}"}
    end
  end

  def load(nil, _loader, _params), do: {:ok, nil}
  def load(_other, _loader, _params), do: :error

  defp get_type(data) do
    with true <- Map.has_key?(data, @discriminator) do
      Map.get(data, @discriminator)
      |> case do
        nil -> {:error, "invalid polyjuice type"}
        val -> {:ok, to_string(val)}
      end
    else
      _ -> {:error, "polyjuice requires :#{@discriminator}"}
    end
  end

  defp get_module({:ok, params}, type) do
    get_in(params, [:values, String.to_atom(type)])
    |> case do
      nil -> {:error, "invalid polyjuice type"}
      mod -> {:ok, mod}
    end
  end

  @impl Ecto.ParameterizedType
  def cast(data, params) when is_map(data) do
    with {:ok, type} <- get_type(data),
         {:ok, module} <- get_module(params, type) do
      {:ok, struct!(module, data)}
    end
  end

  def cast(%module{} = struct, params) do
    allowed_modules = Keyword.values(params.schemas)

    case Enum.member?(allowed_modules, module) do
      true -> {:ok, struct}
      false -> {:error, "Invalid polyjuice struct module."}
    end
  end

  def cast(nil, _params), do: {:ok, nil}
  def cast(_other, _params), do: :error
end
