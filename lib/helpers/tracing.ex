alias Lens2.Helpers.Tracing

defmodule Tracing do
  @moduledoc false

  import TypedStruct
  use Private
  use Lens2
  alias Tracing.{Log, Mutable}

  defmodule LogItem do
    typedstruct do
      field :call, String.t, enforce: true
      field :container, String.t, enforce: true
      field :gotten, String.t
      field :updated, String.t
    end

    def on_entry(name, args, container) do
      %__MODULE__{call: call_string(name, args), container: inspect(container)}
    end

    def on_exit(log_item, gotten, updated) do
      %{log_item | gotten: inspect(gotten), updated: inspect(updated)}
    end

    defp call_string(name, args) do
      formatted_args = Enum.map(args, & inspect(&1))
      "#{name}(#{Enum.join(formatted_args, ",")})"
    end
  end


  # External entry points

  def function_name(original_name) do
    String.to_atom("tracing_#{original_name}")
  end


  def log_entry(name, args, container) do
    case Mutable.current_nesting() do
      nil ->
        Mutable.remember_nesting(0)
        log_entry(name, args, container)
      _ ->
        log(name, args, container)
        Mutable.increment_nesting()
    end
  end

  def log_exit(result, on_level_zero \\ &spill_log/0) do
    Mutable.decrement_nesting()

    log(result)

    if Mutable.current_nesting() == 0 do
      result = on_level_zero.()
      Mutable.forget_log()
      result  # result is used by a test
    end
  end

  def spill_log() do
    log = Mutable.peek_at_log() |> prettify_calls
    for item <- outer_to_inner_items(log) do
      IO.puts("#{item.call} || #{item.container}")
    end

    for item <- inner_to_outer_items(log) do
      IO.puts("#{item.call} || #{item.gotten} || #{item.updated}")
    end
  end

  private do # Manipulating the process map
    def log(name, args, container) do
      LogItem.on_entry(name, args, container)
      |> Mutable.remember_new_item
    end

    def log({gotten, updated}) do
      Mutable.peek_at_log()[Mutable.current_nesting()]
      |> LogItem.on_exit(gotten, updated)
      |> Mutable.update_previous_item
    end

  end

  private do # prettification

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
  end


  # defp nesting_due_to_name(name),
  #      do: String.length(Atom.to_string(name))


  private do # miscellaneous utilities
    def padding(n), do: String.duplicate(" ", n)
  end


end
