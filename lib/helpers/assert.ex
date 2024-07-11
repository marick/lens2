alias Lens2.Helpers

defmodule Helpers.AssertionError do
  @moduledoc false
  defexception [:message]
end

defmodule Helpers.Assert do
  @doc "Raise an AssertionError error if the expression is false."
  defmacro assert(expression) do
    code = Macro.to_string(expression)
    quote do
      unless unquote(expression) do
        raise(Helpers.AssertionError, "#{unquote(code)} is not truthy")
      end
    end
  end
end
