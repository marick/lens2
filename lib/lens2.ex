defmodule Lens2 do
  @moduledoc """
  `Use` this module to `alias` or `import` all the right files.

  It also defines the types used in specs.

  """

  @typedoc "Conceptually, a set of pointers into specified locations in a `container`."
  @type lens :: Access.access_fun

  @typedoc "A nested data structure described by a `lens`."
  @type container :: any

  @typedoc "The value at a place pointed to by a `lens`."
  @type value :: any

  @typedoc "A `value`, but named differently so it's clear it's been updated by the application of some function."
  @type updated_value :: value

  defmacro __using__(_opts \\ []) do
    quote do
      alias Lens2.Lenses, as: Lens
      import Lens2.Compatible.Macros
      alias Lens2.Deeply
    end
  end
end
