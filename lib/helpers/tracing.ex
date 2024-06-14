defmodule Lens2.Helpers.Tracing do
  @moduledoc false

  import TypedStruct

  defmodule LogItem do
    typedstruct do
      field :call_string, String.t, enforce: true
      field :container, any, enforce: true
      field :gotten, any
      field :updated, any
    end

    def entry(call_string, container) do
      %__MODULE__{call_string: call_string, container: container}
    end

    def exit(log_entry, gotten, updated) do
      %{log_entry | gotten: gotten, updated: updated}
    end
  end



  def function_name(original_name) do
    String.to_atom("tracing_#{original_name}")
  end

  def entry(name, args, container) do
    case current_nesting() do
      nil ->
        remember_nesting(0)
        entry(name, args, container)
      _ ->
        log(call(name, args), container)
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


  @log :lens_trace_log
  @nesting :lens_trace_nesting


  def log(call, container) do
    LogItem.entry(call, container)
    |> update_and_stash
  end

  def log({gotten, updated}) do
    peek_at_log()[current_nesting()]
    |> LogItem.exit(gotten, updated)
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


  # defp nesting_due_to_name(name),
  #      do: String.length(Atom.to_string(name))

  # defp padding(n), do: String.duplicate(" ", n)

  defp call(name, args) do
    formatted_args = Enum.map(args, & inspect(&1))
    "#{name}(#{Enum.join(formatted_args, ",")})"
  end
end
