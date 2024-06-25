alias Lens2.Helpers.Section

defmodule Section do
  @moduledoc false

  defmacro section(_comment, do: block) do
    quote do
      unquote(block)
    end
  end
end
