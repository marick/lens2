defmodule Compatibility.Case do
  defmacro __using__(opts) do
    quote do
      use ExUnit.Case, unquote(opts)
      use Lens2.Lens1.Facade
      use FlowAssertions
      require Integer
   end
  end
end
