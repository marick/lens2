alias Lens2.Tracing
import TypedStruct

defmodule Tracing.Get.Value do
  @moduledoc false
  alias Tracing.Common

  typedstruct enforce: true  do
    field :direction,     :> | :<
    field :output,        String.t,   default: ""  #builds over time
  end

  def new(%{direction: :>, container: value}),
      do: %__MODULE__{direction: :>, output: Common.stringify(value)}
  def new(%{direction: :<, gotten: value}),
      do: %__MODULE__{direction: :<, output: Common.stringify(value)}
end

typedstruct module: Tracing.Get.Key, enforce: true do
  field :direction,  :> | :<
  field :level,      integer
  field :repetition, integer
end



defmodule Tracing.Gets do
  @moduledoc false
end
