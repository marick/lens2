defmodule Lens2.Lenses do

  @moduledoc """
  Makes all the predefined lens-makers available.
  """

  alias Lens2.Lenses.{Basic, Indexed, Combine, Keyed}
  import Lens2.Helpers.Delegate
  use Lens2.Lenses.Use
end