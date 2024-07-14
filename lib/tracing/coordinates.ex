alias Lens2.Tracing
import TypedStruct

defmodule Tracing.Coordinate do
  typedstruct enforce: true do
    field :direction, :< | :>
    field :nesting, [non_neg_integer]
  end

  def new(direction, nesting),
      do: struct(__MODULE__, direction: direction, nesting: nesting)

  def first_descent, do: new(:>, [0])
  def final_retreat, do: new(:<, [0])

  # The actions a coordinate may represent.
  def continue_deeper, do: :continue_deeper
  def begin_retreat, do: :begin_retreat
  def continue_retreat, do: :continue_retreat
  def turn_deeper, do: :turn_deeper


  def un_nest(%{direction: :>, nesting: [_ | tail]}), do: new(:>, tail)

  def reverse_direction(%{direction: direction, nesting: nesting}) do
    case direction do
      :> -> new(:<, nesting)
      :< -> new(:>, nesting)
    end
  end

  def previous(%{direction: :>, nesting: [head | tail]}) do
    new(:>, [head-1 | tail])
  end
end

defmodule Tracing.Coordinate.Maker do
  alias Tracing.Coordinate

  typedstruct enforce: true do
    field :last_nesting, [non_neg_integer], default: [0]
    field :use_counts, %{non_neg_integer => non_neg_integer}, default: %{0 => 1}
  end

  def new, do: %__MODULE__{}

  def new(last_nesting, use_counts) do
    %__MODULE__{last_nesting: last_nesting, use_counts: use_counts}
  end

  def refine(raw_material) do
    directions = Enum.map(raw_material, & &1.direction)
    Enum.zip(directions, tl(directions))
  end

  def from([head | _rest] = raw_material) when is_map(head),
      do: from(refine(raw_material))

  def from(pairs) do
    state = new()
    [ Coordinate.new(:>, state.last_nesting) | consume(pairs, state) ]
  end

  def consume([], _state), do: []

  def consume([pair | rest], state) do
    {coordinate, next_state} =
      case pair do
        {:>, :>} -> continue_deeper(state)
        {:>, :<} -> begin_retreat(state)
        {:<, :<} -> continue_retreat(state)
        {:<, :>} -> turn_deeper(state)
      end
    [ coordinate | consume(rest, next_state) ]
  end


  def continue_deeper(%{last_nesting: last_nesting, use_counts: use_counts}) do
    this_level = length(last_nesting)
    this_nesting = [ Map.get(use_counts, this_level, 0) | last_nesting]
    use_counts_now = Map.update(use_counts, this_level, 1, & &1 + 1)
    {Coordinate.new(:>, this_nesting), new(this_nesting, use_counts_now)}
  end

  def begin_retreat(state) do
    {Coordinate.new(:<, state.last_nesting), state}
  end

  def continue_retreat(state) do
    this_nesting = tl(state.last_nesting)
    { Coordinate.new(:<, this_nesting), %{state | last_nesting: this_nesting} }
  end

  def turn_deeper(%{last_nesting: last_nesting, use_counts: use_counts}) do
    this_level = length(last_nesting)-1
    this_nesting = [ use_counts[this_level] | tl(last_nesting) ]
    use_counts_now = Map.update!(use_counts, this_level, & &1+1)

    {Coordinate.new(:>, this_nesting), new(this_nesting, use_counts_now)}
  end

  def classify_actions(pairs) do
    for pair <- pairs do
      case pair do
        {:>, :>} -> Coordinate.continue_deeper
        {:>, :<} -> Coordinate.begin_retreat
        {:<, :<} -> Coordinate.continue_retreat
        {:<, :>} -> Coordinate.turn_deeper
      end
    end
  end


end
