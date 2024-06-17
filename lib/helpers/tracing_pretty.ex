alias Lens2.Helpers.Tracing

defmodule Tracing.Pretty do
  use Lens2
  use Private
  alias Tracing.{Line, EntryLine,ExitLine}

  @keys_that_matter [:call, :container, :gotten, :updated]

  def prettify(log) do
    log
    |> indent_calls
    |> align_common_substrings
    |> equalize_widths(@keys_that_matter)
  end

  private do #indent_calls
    # We want the nesting structure to show by putting blanks on the left
    # From this:
    #
    #     key?(:b)
    #     key?(:c)
    #     <key?(:c)
    #     key?(:b)
    #
    # to this:
    #
    #     >key?(:b)
    #         >key?(:c)
    #         <key?(:c)
    #     <key?(:b)

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

    def pad_left(n, pointer, call), do: padding(n) <> pointer <> call

    def length_of_name(call) do
      [name, _rest] = String.split(call, "(")
      String.length(name)
    end
  end

  private do # align_common_substrings
    # From this:
    #
    #   %{a: %{b: %{c: %{d: 1}}}}
    #   %{b: %{c: %{d: 1}}}
    #   %{c: %{d: 1}}
    #   %{d: 1}
    #
    # to this:
    #
    #   %{a: %{b: %{c: %{d: 1}}}}
    #        %{b: %{c: %{d: 1}}}
    #             %{c: %{d: 1}}
    #                  %{d: 1}

    def align_common_substrings(log) do
      log
      |> split_lines_at_change_of_direction
      |> Enum.map(&align_chunk/1)
      |> Enum.concat
    end

    def split_lines_at_change_of_direction(log) do
      Enum.chunk_by(log, &Line.entering?/1)
    end

    def align_chunk(lines) do
      lines
    end

    def shift_to_align(shorter, longer) do
      regex = Regex.escape(shorter) |> Regex.compile!
      case Regex.run(regex, longer, return: :index) do
        nil ->
          shorter
        [{start, _length}] ->
          padding(start) <> shorter
      end
    end
  end

  private do # equalize_widths
    # We want all values in a particular output column to have a non-ragged right margin.
    #
    # From this:
    #
    #      [nil] ||                %{d: :NEW}
    #     [[nil]] ||           %{c: %{d: :NEW}}
    #    [[[nil]]] ||      %{b: %{c: %{d: :NEW}}}
    #   [[[[nil]]]] || %{a: %{b: %{c: %{d: :NEW}}}}
    #
    # ... to this:
    #
    #      [nil]    ||                %{d: :NEW}
    #     [[nil]]   ||           %{c: %{d: :NEW}}
    #    [[[nil]]]  ||      %{b: %{c: %{d: :NEW}}}
    #   [[[[nil]]]] || %{a: %{b: %{c: %{d: :NEW}}}}
    #
    # Strictly, only the `:call` and `:container` fields need to be adjusted,
    # because they're the only fields that have other fields printed after them.
    # But might as well do them all, so that copy-and-paste gives a proper rectangle
    # on the offhand chance someone wants to annotate on the right.

    def equalize_widths(log, keys_to_adjust) do
      key_to_length = max_lengths(log, keys_to_adjust)

      line_field_adjuster = fn line_value, map_value ->
        needed = map_value - String.length(line_value)
        line_value <> padding(needed)
      end

      for line <- log do
        Line.adjust_line_using_map(line, key_to_length, keys_to_adjust, line_field_adjuster)
      end
    end

    def max_lengths(log, keys_to_count) do
      starting = for key <- keys_to_count, into: %{}, do: {key, 0}

      map_field_adjuster = fn map_value, line_value ->
        max(map_value, String.length(line_value))
      end

      Enum.reduce(log, starting, fn line, improving_map ->
        Line.adjust_map_using_line(improving_map, line, keys_to_count, map_field_adjuster)
      end)
    end
  end

  private do  # common
    def padding(n), do: String.duplicate(" ", n)
  end
end
