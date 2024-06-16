alias Lens2.Helpers.Tracing

defmodule Tracing.Pretty do
  use Lens2
  use Private
  alias Tracing.{Line, EntryLine,ExitLine}

  @keys_that_matter [:call, :container, :gotten, :updated]

  def prettify(log) do
    log
    |> indent_calls
    |> pad_right(@keys_that_matter)
  end

  private do   # main utilities

    def indent_calls(log) do
      reduce_one_line = fn line, {left_margin, building_log} ->
        case line do
          %EntryLine{} ->
            padded = Map.update!(line, :call, & pad_left(left_margin, ">", &1))
            left_margin = left_margin + length_of_name(line.call)
            {left_margin, [padded | building_log]}
          %ExitLine{} ->
            left_margin = left_margin - length_of_name(line.call)
            padded = Map.update!(line, :call, & pad_left(left_margin, "<", &1))
            {left_margin, [padded | building_log]}
        end
      end

      log
      |> Enum.reduce({0, []}, reduce_one_line)
      |> elem(1)
      |> Enum.reverse
    end

    def pad_right(log, keys_to_adjust) do
      key_to_length = max_lengths(log, keys_to_adjust)

      line_field_adjuster = fn line_value, map_value ->
        needed = map_value - String.length(line_value)
        line_value <> padding(needed)
      end

      for line <- log do
        Line.adjust_line_using_map(line, key_to_length, keys_to_adjust, line_field_adjuster)
      end
    end
  end

  private do  # utilities
    def max_lengths(log, keys_to_count) do
      starting = for key <- keys_to_count, into: %{}, do: {key, 0}

      map_field_adjuster = fn map_value, line_value ->
        max(map_value, String.length(line_value))
      end

      Enum.reduce(log, starting, fn line, improving_map ->
        Line.adjust_map_using_line(improving_map, line, keys_to_count, map_field_adjuster)
      end)
    end

    def length_of_name(call) do
      [name, _rest] = String.split(call, "(")
      String.length(name)
    end

    def padding(n), do: String.duplicate(" ", n)
    def pad_left(n, pointer, call), do: padding(n) <> pointer <> call

  end
end
