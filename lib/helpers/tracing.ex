defmodule Lens2.Helpers.Tracing do
  @moduledoc false

  import TypedStruct
  use Private

  defmodule LogItem do
    typedstruct do
      field :call, String.t, enforce: true
      field :container, any, enforce: true
      field :gotten, any
      field :updated, any
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

  def entry(name, args, container) do
    case current_nesting() do
      nil ->
        remember_nesting(0)
        entry(name, args, container)
      _ ->
        log(name, args, container)
#        IO.puts(["> #{call(name, args)} ||   #{inspect data}"])
        increment_nesting()
    end
  end

  def exit(result, on_level_zero \\ &spill_log/0) do
    decrement_nesting()

    log(result)

#    IO.puts(["< #{call(name, args)} ||   #{inspect result}"])
    if current_nesting() == 0 do
      result = on_level_zero.()
      forget_tracing()
      result  # result is used by a test
    end
  end

  def spill_log() do
  end

  private do # Manipulating the process map

    @log :lens_trace_log
    @nesting :lens_trace_nesting


    def log(name, args, container) do
      LogItem.on_entry(name, args, container)
      |> update_and_stash
    end

    def log({gotten, updated}) do
      peek_at_log()[current_nesting()]
      |> LogItem.on_exit(gotten, updated)
      |> update_and_stash
    end

    def forget_tracing() do
      Process.delete(@log)
      Process.delete(@nesting)
    end


    def update_and_stash(item) do
      updated =
        Process.get(@log, %{})
        |> Map.put(current_nesting(), item)
      Process.put(@log, updated)
    end

    def peek_at_log(), do: Process.get(@log)
    def peek_at_log(level: level), do: peek_at_log()[level]


    def current_nesting, do: Process.get(@nesting)
    def remember_nesting(n), do: Process.put(@nesting, n)
    def increment_nesting(),
        do: remember_nesting(current_nesting() + 1)
    def decrement_nesting(),
        do: remember_nesting(current_nesting() - 1)

  end

  private do # prettification

    def prettify_calls(log) do
      log
      |> indent_calls(:call)
      |> pad_right(:call)
    end

    def indent_calls(log, key) do
      levels = map_size(log)
      {_, replacements} =
        Enum.reduce(0..levels-1, {0, []}, fn level, {left_margin, replacements} ->
          current = log[level][key]
          updated = padding(left_margin) <> current
          {left_margin + length_of_name(current), [{level, updated} | replacements]}
        end)
      replace_field(log, key, replacements)
    end

    def max_length(log, key) do
      levels = map_size(log)
      (for level <- 0..levels-1, do: String.length(log[level][key]))
      |> Enum.max
    end

    def pad_right(log, key) do
      length = max_length(log, key)
      levels = map_size(log)

      replacements =
        for level <- 0..levels-1 do
          current = log[level][key]
          addition = padding(length - String.length(current))
          {level, current <> addition}
        end
      replace_field(log, key, replacements)
    end

    def replace_field(log, key, replacements) do
      Enum.reduce(replacements, log, fn {level, replacement}, new_log ->
        put_in(new_log, [level, key], replacement)
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

    def function_name(original_name) do
      String.to_atom("tracing_#{original_name}")
    end
  end


end
