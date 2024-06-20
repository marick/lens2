alias Lens2.Helpers.Tracing

defmodule Tracing do
  @moduledoc false
  alias Tracing.{Mutable,Pretty}
  alias Tracing.{EntryLine,ExitLine}

  def function_name(original_name) do
    String.to_atom("tracing_#{original_name}")
  end


  def log_entry(name, args, container) do
    EntryLine.new(name, args, container) |>  Mutable.add_log_item
  end

  def log_exit(name, args, {gotten, updated}, when_finished \\ &spill_log/0) do
    ExitLine.new(name, args, gotten, updated) |>  Mutable.add_log_item
    if Mutable.empty_stack?() do
      result = when_finished.()
      Mutable.forget_log()
      result  # result is used by a test
    end
  end

  def spill_log() do
    log =
      Mutable.peek_at_log()
      |> Pretty.prettify

    IO.puts("\n")

    for line <- log do
      case line do
        %EntryLine{} ->
          IO.puts("#{line.call} || #{line.container}")
        %ExitLine{} ->
          IO.puts("#{line.call} || #{line.gotten} || #{line.updated}")
      end
    end
  end
end
