defmodule Lens2 do
  @moduledoc """
  `Use` this module to `alias` or `import` all the right files.


  """
  defmacro __using__(_opts \\ []) do
    quote do
      alias Lens2.Lenses.All, as: Lens
      import Lens2.Compatible.Macros
      alias Lens2.Deeply
    end
  end
end
