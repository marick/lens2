defmodule Lens2.Compatible do

  defmacro __using__(_opts \\ []) do
    quote do
      alias Lens2.Compatible, as: Lens
      import Lens2.Compatible.Macros
    end
  end

  alias Lens2.Compatible.Operations
  use Lens2.Compatible.OriginalLenses

  defdelegate get_and_map(lens, data, fun), to: Operations
  defdelegate to_list(lens, data), to: Operations
  defdelegate each(lens, data, fun),to: Operations
  defdelegate map(lens, data, fun),to: Operations
  defdelegate put(lens, data, value),to: Operations
  defdelegate one!(lens, data),to: Operations
end
