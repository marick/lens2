defmodule Lens2.Deflens do
  defmacro __using__(_) do
    quote do
      require Lens2.Compatible.Macros
      import Lens2.Compatible.Macros
    end
  end
end
