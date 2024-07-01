alias Lens2.Tracing

defmodule Tracing do
  alias Tracing.State
  defmacro wrap(operations, do: body) do
    quote do
      case State.get_operations do
        nil ->
          State.put_operations(unquote(operations))
          result = unquote(body)
          State.delete_operations
          result
        _ ->
          unquote body
      end
    end
  end
end
