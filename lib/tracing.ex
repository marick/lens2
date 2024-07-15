alias Lens2.Tracing

defmodule Tracing do
  alias Tracing.State
  defmacro wrap(operations, do: body) do
    quote do
      if State.tracing_already_in_progress? do
        unquote body
      else
        State.put_operations(unquote(operations))
        result = unquote(body)
        State.delete_operations
        result
      end
    end
  end
end
