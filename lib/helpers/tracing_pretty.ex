alias Lens2.Helpers.Tracing

defmodule Tracing.Pretty do
  use Lens2
  use Private
  alias Tracing.Log


  def prettify(log) do
    prettify_calls(log)
  end


  def prettify_calls(log) do
    log
    |> indent_calls(:call)
    |> pad_right(:call)
  end

  def indent_calls(log, key) do
    in_order_reduce(log, key, 0, fn left_margin, current ->
      {left_margin + length_of_name(current), padding(left_margin) <> current}
    end)
  end

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

  def max_length(log, key) do
    Deeply.to_list(log, Log.all_fields(key))
    |> Enum.map(&String.length/1)
    |> Enum.max
  end

  def outer_to_inner_levels(log) do
    Range.new(0, map_size(log)-1, 1)
  end

  def inner_to_outer_levels(log) do
    Range.new(map_size(log)-1, 0, -1)
  end

  def outer_to_inner_items(log) do
    outer_to_inner_levels(log)
    |> Enum.map(fn level -> log[level] end)
  end

  def inner_to_outer_items(log) do
    inner_to_outer_levels(log)
    |> Enum.map(fn level -> log[level] end)
  end

  def pad_right(log, key) do
    length = max_length(log, key)

    Deeply.update(log, Log.all_fields(key), fn current ->
      current <> padding(length - String.length(current))
    end)
  end

  def replace_field(log, key, replacements) do
    Enum.reduce(replacements, log, fn {level, replacement}, new_log ->
      Deeply.put(new_log, Log.one_field(level, key), replacement)
    end)
  end


  def length_of_name(call) do
    [name, _rest] = String.split(call, "(")
    String.length(name)
  end

  def padding(n), do: String.duplicate(" ", n)
end
