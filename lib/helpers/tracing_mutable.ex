alias Lens2.Helpers.Tracing

defmodule Tracing.Mutable do
  alias Tracing.{EntryLine, ExitLine}
  use Private

  @log :lens_trace_log
  @next_level :lens_next_level

  def forget_log() do
    Process.put(@log, [])
    Process.put(@next_level, 0)
  end

  def empty_stack?() do
    ensure_log()
    Process.get(@next_level) == 0
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
