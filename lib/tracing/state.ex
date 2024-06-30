alias Lens2.Tracing

defmodule State.Macros do
  defmacro crud(suffix, key) do
    name_for = fn prefix -> String.to_atom("#{prefix}_#{suffix}") end

    quote do
      def unquote(name_for.(:put))(value), do: Process.put(unquote(key), value)
      def unquote(name_for.(:get))(), do: Process.get(unquote(key))
      def unquote(name_for.(:delete))(), do: Process.delete(unquote(key))
    end
  end
end

defmodule Tracing.State do
  import State.Macros

  @operations :_tracing_operations

  crud(:operations, @operations)
end
