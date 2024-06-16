alias Lens2.Helpers.Tracing


defmodule Tracing.Line do
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

end

defmodule Tracing.EntryLine do
  import TypedStruct

  typedstruct do
    field :call, String.t, enforce: true
    field :container, String.t, enforce: true
  end

  def new(name, args, container),
      do: %__MODULE__{call: Tracing.Line.call_string(name, args), container: inspect(container)}
end

defmodule Tracing.ExitLine do
  import TypedStruct

  typedstruct do
    field :call, String.t, enforce: true
    field :gotten, String.t
    field :updated, String.t
  end

  def new(name, args, gotten, updated) do
    %__MODULE__{call: Tracing.Line.call_string(name, args),
                gotten: inspect(gotten),
                updated: inspect(updated)}
  end

end
