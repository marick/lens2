alias Lens2.Helpers.Tracing


defmodule Tracing.EntryLine do
  @moduledoc false
  import TypedStruct
  alias Tracing.Line

  typedstruct do
    field :call, String.t, enforce: true
    field :container, String.t, enforce: true
  end

  def new(name, args, container),
      do: new(Tracing.Line.call_string(name, args), Line.i(container))

  def new(call_string, container) when is_binary(call_string),
      do: %__MODULE__{call: call_string, container: container}
end

defmodule Tracing.ExitLine do
  @moduledoc false
  import TypedStruct
  alias Tracing.Line

  typedstruct do
    field :call, String.t, enforce: true
    field :gotten, String.t
    field :updated, String.t
  end

  def new(name, args, gotten, updated) do
    new(Tracing.Line.call_string(name, args), Line.i(gotten), Line.i(updated))
  end

  def new(call_string, gotten_string, updated_string) do
    %__MODULE__{call: call_string,
                gotten: gotten_string,
                updated: updated_string}
  end
end


defmodule Tracing.Line do
  @moduledoc false

  def i(data), do: inspect(data, charlists: :as_lists, custom_options: [sort_maps: true])

  def call_string(name, args) do
    formatted_args = Enum.map(args, & inspect(&1))
    "#{name}(#{Enum.join(formatted_args, ",")})"
  end

  def adjust_map_using_line(map, line, keys, f) do
    Enum.reduce(keys, map, fn key, improving_map ->
      case Map.fetch(line, key) do
        {:ok, line_value} ->
          update = f.(Map.fetch!(improving_map, key), line_value)
          Map.put(improving_map, key, update)
        :error ->
          improving_map
      end
    end)
  end

  def adjust_line_using_map(line, map, keys, f) do
    Enum.reduce(keys, line, fn key, improving_line ->
      case Map.fetch(line, key) do
        {:ok, line_value} ->
          update = f.(line_value, map[key])
          Map.put(improving_line, key, update)
        :error ->
          improving_line
      end
    end)
  end

  def entering?([line | _]), do: entering?(line)
  def entering?(line), do: is_struct(line, Tracing.EntryLine)
end
