alias Lens2.Helpers.Tracing

defmodule Tracing.Log do
  use Lens2
  use Private

  deflens all_fields(key), do: Lens.map_values |> Lens.key!(key)
  deflens one_field(level, key), do: Lens.key!(level) |> Lens.key!(key)


  def replace_field(log, key, replacements) do
    Enum.reduce(replacements, log, fn {level, replacement}, new_log ->
      Deeply.put(new_log, one_field(level, key), replacement)
    end)
  end

  def outer_to_inner_items(log),
      do: outer_to_inner_levels(log) |> Enum.map(fn level -> log[level] end)
  def inner_to_outer_items(log),
      do: inner_to_outer_levels(log) |> Enum.map(fn level -> log[level] end)

  private do
    def outer_to_inner_levels(log), do: Range.new(0, map_size(log)-1, 1)
    def inner_to_outer_levels(log), do: Range.new(map_size(log)-1, 0, -1)

    def reduce_levels(log, level_range, key, init, f) do
      {_, replacements} =
        Enum.reduce(level_range, {init, []}, fn level, {acc, replacements} ->

          # current = Deeply.one!(log, Log.one_field(level, key))
          # The above version is better, but interferes with debugging by
          # instrumenting lens functions
          current = log[level] |> Map.get(key)
          {new_acc, replacement} = f.(acc, current)
          {new_acc, [{level, replacement} | replacements]}
        end)
      replace_field(log, key, replacements)
    end

    def in_order_reduce(log, key, init, f) do
      reduce_levels(log, outer_to_inner_levels(log), key, init, f)
    end


  end

end
