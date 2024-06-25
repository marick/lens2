alias Lens2.Helpers.Section

defmodule Section do
  @moduledoc "Idiosyncratic grouping macros"

  defmacro section(_comment, do: block) do
    quote do
      unquote(block)
    end
  end
end
