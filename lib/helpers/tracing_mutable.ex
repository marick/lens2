alias Lens2.Helpers.Tracing

defmodule Tracing.Mutable do
  @moduledoc false

  alias Tracing.{EntryLine, ExitLine}
  use Private

  @log :lens_trace_log
  @next_level :lens_next_level
  @why_are_we_tracing :lens_trace_operations

  def forget_tracing() do
    Process.put(@log, [])
    Process.put(@next_level, 0)
    Process.delete(@why_are_we_tracing)
  end

  def empty_stack?() do
    ensure_log()
    Process.get(@next_level) == 0
  end

  def remember_reasons(list) do
    if Process.get(@why_are_we_tracing) == nil do
      Process.put(@why_are_we_tracing, list)
    end
  end

  def should_show_this_log?(key) do
    case Process.get(@why_are_we_tracing) do
      nil -> # Unless instructed, default to showing both
        true
      reasons ->
        key in reasons
    end
  end

  def add_log_item(%EntryLine{} = line) do
    ensure_log()
    add_to_end(line)
    update_level(1)
  end

  def add_log_item(%ExitLine{} = line) do
    add_to_end(line)
    update_level(-1)
  end

  def peek_at_log(), do: Process.get(@log) |> Enum.reverse
  def peek_at_log(at: index), do: peek_at_log() |> Enum.at(index)

  private do
    def ensure_log() do
      if Process.get(@log) == nil do
        Process.put(@log, [])
        Process.put(@next_level, 0)
      end
    end

    def add_to_end(item),
        do: Process.put(@log, [item | Process.get(@log)])

    def update_level(amount) do
      Process.put(@next_level, Process.get(@next_level) + amount)
    end
  end

end
