defmodule Lens2.Lenses do

  alias Lens2.Lenses

  @moduledoc """
  Aggregates all the lenses in
  `Lens2.Lenses.Combine`,
  `Lens2.Lenses.Enum`,
  `Lens2.Lenses.Filter`,
  `Lens2.Lenses.Indexed`, and
  `Lens2.Lenses.Keyed`.

  Traditionally, this module is aliased to `Lens`, so that the makers
  have the same name as in the [Lens 1](https://hexdocs.pm/lens/readme.html) package. See the `Lens2` module.
  """

  import Lens2.Helpers.Delegate
  use Lens2.Lenses.Use
end
