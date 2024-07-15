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
#        State.patch_final_gotten(result)
        State.destructive_read
        result
      end
    end
  end
end
