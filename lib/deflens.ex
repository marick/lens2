defmodule Lens2.Deflens do
  @moduledoc """
  `deflens` creates lenses compatible with the pipeline (`|>`) operator.


  """
  defmacro __using__(_) do
    quote do
      require Lens2.Compatible.Macros
      import Lens2.Compatible.Macros
    end
  end
end
