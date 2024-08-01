defmodule Lens2.Deeply do
  @moduledoc """
  Operations that work with lenses. The API is close to the familiar `get`, `put`, `update` one.

  There are two differences to note:

  1. In most APIs with `get` (like `Map` and `Keyword`) return a
     single value from a container. Lenses point at zero or more
     places within a container, so the natural "read" operation is to
     return a collection (specifically, a `List`). Naming that
     operation `get` invites mistakes, so the fundamental "read"
     operation is `Lens2.Deeply.get_all/2`. In the case where you know there's
     a single value being returned, you can use `Lens2.Deeply.get_only/2` to avoid having
     to pick a value out of a singleton list.

  2. In those Elixir core APIs, it's the operations that decides what to do about
     missing keys and the like. Consider `Map.update/4` (use a default)
     and `Map.update!/3` (raise an error). In this lens package, it's the
     *lens* that decides. See, for example, `Lens2.Lenses.Keyed.key/1`,
     `Lens2.Lenses.Keyed.key?/1`, and `Lens2.Lenses.Keyed.key!/1`.

  The functions in this module have simple implementations because lenses are
  compatible with the `Access` behaviour. For example,
  `Lens2.Deeply.put/3` is just a wrapper around a call to
  `put_in/3`:

       def put(container, lens, value),
           do: put_in(container, [lens], value)

  You can use the `Kernel` functions if you prefer. Don't forget the bracket!

  For convenience and backwards compatibility, this package also provides the [Lens 1](https://hexdocs.pm/lens/readme.html) functions `to_list/2`, and `one!/2`.

  """
  @doc ~S"""
  Returns a list of the values that the lens points at.

      iex>  lens = Lens.map_values
      iex>  %{a: 1, b: 2, c: 3} |> Deeply.get_all(lens) |> Enum.sort
      [          1,    2,    3]

  `get_all` produces its result with `get_in/2`.
  """

  @spec get_all(Lens2.container, Lens2.lens) :: list(Lens2.value)
  def get_all(container, lens) do
    Kernel.get_in(container, [lens])
  end


  @doc ~S"""
  Returns a list of the values that the lens points at.

  This is the name the `get_all/2` function had in [Lens 1](https://hexdocs.pm/lens/readme.html). I prefer `get_all/2`,
  note least because if I forget and use `Deeply.get`, I get a helpful error message:

      Lens2.Deeply.get/2 is undefined or private. Did you mean:

      * get_all/2
      * get_only/2

  However, `to_list` also has its a strong legacy in the Elixir
  tradition, so you choose.

      iex>  lens = Lens.map_values
      iex>  %{a: 1, b: 2, c: 3} |> Deeply.to_list(lens) |> Enum.sort
      [          1,    2,    3]

  `get_all` produces its result with `get_in/2`.
  """
  @spec to_list(Lens2.container, Lens2.lens) :: list(Lens2.value)
  def to_list(container, lens), do: get_all(container, lens)

  @doc ~S"""
  Return the single value the lens points at.

  This calls `get_all/2` and unwraps the single value in the resulting list.
  If that list has a different number of elements, a `MatchError` will be raised.

      iex>  lens = Lens.key(:a)
      iex>  %{a: 1, b: 2, c: 3} |> Deeply.get_only(lens)
      1
  """
  @spec get_only(Lens2.container, Lens2.lens) :: Lens2.value
  def get_only(container, lens) do
    [result] = get_all(container, lens)
    result
  end

  @doc ~S"""
  Return the single value the lens points at.

  This is the name the `get_only/2` function had in [Lens 1](https://hexdocs.pm/lens/readme.html). I prefer `get_only/2`,
  but if you prefer this name, more power to you.

  This calls `get_all/2` and unwraps the single value in the resulting list.
  If that list has a different number of elements, a `MatchError` will be raised.

      iex>  lens = Lens.key(:a)
      iex>  %{a: 1, b: 2, c: 3} |> Deeply.one!(lens)
      1
  """
  @spec one!(Lens2.container, Lens2.lens) :: Lens2.value
  def one!(container, lens), do: get_only(container, lens)

  # ===========

  @doc ~S"""
  Put a specific value into all the places the lens points at.

      iex>  lens = Lens.keys([:a, :c])
      iex>  %{a:    1,  b: 2,  c:    3} |> Deeply.put(lens, :NEW)
      %{      a: :NEW,  b: 2,  c: :NEW}

  `put` produces its result with `put_in/3`.
  """
  @spec put(Lens2.container, Lens2.lens, Lens2.value) :: Lens2.container
  def put(container, lens, value) do
    Kernel.put_in(container, [lens], value)
  end

  # ============
  @doc ~S"""

  Apply the given function to every value pointed at by the lens,
  returning an updated container.

      iex>  lens = Lens.keys([:a, :c])
      iex>  updater = & &1 * 1000
      iex>  %{a:    1,  b: 2,  c:    3} |> Deeply.update(lens, updater)
      %{      a: 1000,  b: 2,  c: 3000}

  This corresponds to `map` in the original
  [`Lens`]((https://hexdocs.pm/lens/readme.html)) package. The name
  has been changed for consistency with `Access`.

  `update` produces its result with `update_in/3`.
  """
  @spec update(Lens2.container, Lens2.lens, (Lens2.value -> Lens2.updated_value)) :: Lens2.container
  def update(container, lens, fun) do
    Kernel.update_in(container, [lens], fun)
  end

  @doc ~S"""
  Retrieve all pointed-at values and, at the same time, update them.

  The return value is a tuple with two elements:
  1. A list (as with `get_all/2`) of the values *before* the update.
  2. The entire container, updated as with `update/3`.

         iex>  lens = Lens.keys([:a, :c])
         ...>  fun = fn value ->
         ...>    {value, value * 1000}
         ...>  end
         iex>  %{a:    1,  b: 2,  c:    3} |> Deeply.get_and_update(lens, fun)
         {     [       1,               3],
               %{a: 1000,  b: 2,  c: 3000}
         }

  `get_and_update` produces its result with `get_and_update_in/3`.
  """
  @spec get_and_update(Lens2.container, Lens2.lens, (Lens2.value -> {Lens2.value, Lens2.updated_value})) :: {list(Lens2.value), Lens2.container}
  def get_and_update(container, lens, tuple_returner) do
    Kernel.get_and_update_in(container, [lens], tuple_returner)
  end

  # =====


  @doc ~S"""
  Call a function (for side effects) on each pointed-at value.

      iex>  container = %{a: 1,  b: 2, c: 3}
      iex>  lens = Lens.keys([:a, :c])
      iex>  Deeply.each(container, lens, fn value ->
      ...>    send(self(), "sending #{value}")
      ...>  end)
      iex>  assert_receive("sending 1")
      iex>  assert_receive("sending 3")

  Any return value from the `fun` is ignored.
  """
  @spec each(Lens2.container, Lens2.lens, (Lens2.value -> no_return)) :: :ok
  def each(container, lens, fun),
      do: get_all(container, lens) |> Enum.each(fun)
end
