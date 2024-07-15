defmodule Lens2.Case do
  defmacro __using__(opts) do
    quote do
      use ExUnit.Case, unquote(opts)
      use Lens2
      use FlowAssertions
   end
  end
end
