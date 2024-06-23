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

  def log_exit(name, args, {gotten, updated}) do
    ExitLine.new(name, args, gotten, updated) |>  Mutable.add_log_item
    if Mutable.empty_stack?() do
      spill_log()
      Mutable.forget_tracing()
    end
  end

  def spill_log() do
    common =
      Mutable.peek_at_log()
      |> Pretty.common_adjustments

    if Mutable.should_show_this_log?(:get),
       do: spill_one_result(common, :gotten, "GET")
    if Mutable.should_show_this_log?(:update),
       do: spill_one_result(common, :updated, "UPDATE")
  end

  def spill_one_result(log, result_key, operation_tag) do
    aligned =
      log
      |> Pretty.align_common_substrings(result_key)
      |> Pretty.equalize_widths([:call, :container, result_key])


    column_separator = " || "
    position_for_comment =
      String.length(Enum.at(log, 0).container) + String.length(column_separator) + 1
    # The above doesn't actually align the way I expected, but it actually looks decent
    # so I won't bother figuring it out.
    IO.puts("\n#{Pretty.padding(position_for_comment)}#{operation_tag}")

    for line <- aligned do
      case line do
        %EntryLine{} ->
          IO.puts("#{line.call} || #{green(line.container)}")
        %ExitLine{} ->
          IO.puts("#{line.call} || #{yellow(Map.get(line, result_key))}")
      end
    end
  end

  defp green(chardata), do: IO.ANSI.format([:green, chardata])
  defp yellow(chardata), do: IO.ANSI.format([:yellow, chardata])

end
