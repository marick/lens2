alias Lens2.Helpers.Tracing

defmodule Tracing.Mutable do

  @log :lens_trace_log
  @nesting :lens_trace_nesting

  def forget_log() do
    Process.delete(@log)
    Process.delete(@nesting)
  end

  def remember_new_item(item) do
    updated =
      Process.get(@log, %{})
      |> Map.put(current_nesting(), item)
    Process.put(@log, updated)
  end

  def update_previous_item(item) do
    remember_new_item(item)
  end

  def current_nesting, do: Process.get(@nesting)

  def peek_at_log(), do: Process.get(@log)
  def peek_at_log(level: level), do: peek_at_log()[level]


  def remember_nesting(n), do: Process.put(@nesting, n)
  def increment_nesting(),
      do: remember_nesting(current_nesting() + 1)
  def decrement_nesting(),
      do: remember_nesting(current_nesting() - 1)



end
