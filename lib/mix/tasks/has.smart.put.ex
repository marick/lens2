defmodule Mix.Tasks.Has.Smart.Put do
  @moduledoc """
  Is the data type smart about "put" operations that produce identical structures?

  A naive implementation of `Map` would be such that:

      iex> Map.get(map, :key)
      :some_value
      iex> Map.put(map, :key, :some_value)

  ... would allocate a completely new map. Maps and structs are, in fact, smarter than
  that. `put` just returns the original map.

  This matters for the current implementation of lenses because
  `Deeply.get_all` will do such equality-preserving puts (and then
  throw the result away). Naive implementations of a container data
  type will do extra work that `get_in` avoids.

  If you're implementing lenses for a new data structure, you nmight want to know
  whether it's smart or naive.

      $ mix has.smart.put
      Is the data structure smart enough to not create an identical copy?
      List: false
      Map: true
      Struct: true
      MapSet: true

  """

  use Mix.Task
  use TypedStruct
  use Lens2

  @impl Mix.Task
  def run([]) do
    IO.puts "Is the data structure smart enough to not create an identical copy?"
    list()
    map()
    struct()
    mapset()
  end

  @doc false
  def check(prefix, original, new) do
    verdict =
      :erts_debug.same(original, new)
      |> inspect

    IO.puts("#{prefix}: #{verdict}")
  end

  @doc false
  def list do
    original = [0, 1]
    new = List.replace_at(original, 1, 1)
    check("List", original, new)
  end

  @doc false
  def map do
    original = %{a: 1}
    new = Map.put(original, :a, 1)
    check("Map", original, new)
  end

  defmodule Point do
    @moduledoc false
    typedstruct do
      field :x, integer
      field :y, integer
    end
  end

  @doc false
  def struct do
    original = %Point{x: 0, y: 1}
    new = Map.put(original, :x, 0)
    check("Struct", original, new)
  end

  @doc false
  def mapset do
    original = MapSet.new([0, 1])
    new = MapSet.put(original, 1)
    check("MapSet", original, new)
  end
end
