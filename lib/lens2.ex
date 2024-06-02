defmodule Lens2 do
  defmacro __using__(_opts \\ []) do
    quote do
      import Lens2.Lenses.{Basic, Listlike, Combine, Maplike, Operations}
      import Lens2.Compatible.Macros
      alias Lens2.Deeply
    end
  end
end
