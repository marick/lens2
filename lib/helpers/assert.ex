alias Lens2.Helpers

defmodule Helpers.AssertionError do
  @moduledoc false
  defexception [:message]
end

defmodule Helpers.Assert do
  @moduledoc false
  @doc "Raise an AssertionError error if the expression is false."
  defmacro assert(expression) do
    code = Macro.to_string(expression)
    quote do
      unless unquote(expression) do
        raise(Helpers.AssertionError, "#{unquote(code)} is not truthy")
      end
    end
  end

  # `defmaker` doesn't cooperate with guards, so need an explicit precondition.
  defmacro assert_list(first_arg) do
    quote do
      unless is_list(unquote(first_arg)) do
        {name, arity} =  __ENV__.function
        raise Helpers.AssertionError, "#{name}/#{arity} takes a list as its argument."
      end
    end
  end

  # `defmaker` doesn't cooperate with guards, so need an explicit precondition.
  defmacro assert_atom(first_arg) do
    quote do
      unless is_atom(unquote(first_arg)) do
        {name, arity} =  __ENV__.function
        raise Helpers.AssertionError, "#{name}/#{arity} takes an atom as its argument."
      end
    end
  end



end
