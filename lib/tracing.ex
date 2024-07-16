alias Lens2.Tracing

defmodule Tracing do
  alias Tracing.State
  defmacro wrap(_operations, do: body) do
    quote do
      if State.tracing_already_in_progress? do
        unquote body
      else
        State.start_log
        result = unquote(body)
        if State.has_accumulated_a_log? do
          #State.patch_final_gotten(result)
          #State.destructive_read
        end
        State.reset
        result
      end
    end
  end
end
