defmodule Lens2 do
  @moduledoc """
  `Use` this module for convenience.

  A module that does that can...

  1. ... access all the lens-making functions from the [Lens 1](https://hexdocs.pm/lens/readme.html) package
     under the same names: `Lens.key/1`, for example. See
     `Lens2.Lenses` for the complete list.

  2. ... make lenses for `MapSet` containers with `Lens.MapSet` and
     lenses for `BiMap` and `BiMultiMap` with `Lens.Bi`. Those are aliases for
     `Lens2.Lenses.MapSet` and `Lens2.Lenses.Bi`.

  3. ... traverse containers with lens-using functions like
     `Deeply.update`. (See `Lens2.Deeply`.)

  3. ... define its own lens makers with `def_raw_maker` and `defmaker`. (See
     `Lens2.Makers`.)


  It also defines the types used in specs.

  """

  @typedoc "Conceptually, a set of pointers into specified locations in a `container`."
  @type lens :: Access.access_fun(container, [value])

  @typedoc "A nested data structure described by a `lens`."
  @type container :: any

  @typedoc "The value at a place pointed to by a `lens`."
  @type value :: any

  @typedoc "A `value`, but named differently so it's clear it's been updated by the application of some function."
  @type updated_value :: value

  @doc """
  Provide standard imports and aliases.

  See the top of this page for more.
  """
  defmacro __using__(_opts \\ []) do
    quote do
      alias Lens2.Lenses, as: Lens
      import Lens2.Makers
      alias Lens2.Deeply
    end
  end
end
