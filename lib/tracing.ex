alias Lens2.Tracing

defmodule Tracing do
  alias Tracing.State
  defmacro wrap(operations, do: body) do
    quote do
      if State.tracing_already_in_progress? do
        unquote body
      else
        State.start_log
        result = unquote(body)
        if State.has_accumulated_a_log? do
          State.patch_final_gotten(result)
          Tracing.spill(unquote(operations))
        end
        State.reset
        result
      end
    end
  end

  def function_name(original_name) do
    String.to_atom("tracing_#{original_name}")
  end

  def spill(operations) do
    alias Tracing.Calls
    log = State.peek_at_log
    call_strings = Calls.log_to_call_strings(log) |> dbg
    colors = for log_item <- log, do: colorizer(log_item.direction)

    if :get in operations do
      gotten_strings = Tracing.Adjust.gotten_strings(log)
        Enum.zip([colors, call_strings, gotten_strings])
        |> complete_lines
        |> Enum.each(&IO.puts/1)
    end
  end

  def colorizer(:>), do: & IO.ANSI.format([:green, &1])
  def colorizer(:<), do: & IO.ANSI.format([:yellow, &1])

  def complete_lines(triples) do
    for {colorizer, left, right} <- triples do
      "#{left} || #{colorizer.(right)}"
    end
  end

end
