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

  def spill(_operations) do
    dbg State.peek_at_log
    # calls =
    # if :get in operations, do: spill_log
    # State.patch_final_gotten(result)
  end
end
