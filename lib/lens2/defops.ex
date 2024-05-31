defmodule Lens2.Defops do
  @moduledoc false


  def get(data, key) do
    case fetch(data, key) do
      :error -> nil
      {:ok, value} -> value
    end
  end

  def put(data, key, value) when is_map(data), do: Map.put(data, key, value)

  def put(data, key, value) do
    {_, updated} = Access.get_and_update(data, key, fn _ -> {nil, value} end)
    updated
  end

  def fetch!(data, key) do
    case fetch(data, key) do
      :error -> raise(KeyError, key: key, term: data)
      {:ok, value} -> value
    end
  end

  def fetch(data, key) when is_map(data), do: Map.fetch(data, key)
  def fetch(data, key), do: Access.fetch(data, key)

  def at(data, index) when is_tuple(data), do: elem(data, index)
  def at(data, index), do: Enum.at(data, index)

  def put_at(data, index, value) when is_tuple(data), do: put_elem(data, index, value)

  def put_at(data, index, value) when is_list(data) do
    List.update_at(data, index, fn _ -> value end)
  end

end
