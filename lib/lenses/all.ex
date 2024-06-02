defmodule Lens2.Lenses.All do

  @moduledoc "If, for some reason, you want a list of all the lenses, here they are."

  alias Lens2.Lenses.{Basic, Indexed, Combine, Keyed}
  import Lens2.Helpers.Delegate
  use Lens2.Compatible.OriginalLenses
end
