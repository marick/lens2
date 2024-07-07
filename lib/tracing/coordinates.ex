alias Lens2.Tracing
import TypedStruct

defmodule Tracing.Coordinate do
  typedstruct enforce: true do
    field :direction, :< | :>
    field :nesting, [non_neg_integer]
  end

  def new(direction, nesting),
      do: struct(__MODULE__, direction: direction, nesting: nesting)
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
        {:<, :>} -> turn_deeper(state)
      end
    [ coordinate | consume(rest, next_state) ]
  end

  def continue_deeper(%{last_nesting: last_nesting, use_counts: use_counts}) do
    this_level = length(last_nesting)
    IO.puts "Need a test to make this fail if reoccupying a level"
    this_nesting = [ 0 | last_nesting]
    use_counts_now = Map.put(use_counts, this_level, 1)
    {Coordinate.new(:>, this_nesting), new(this_nesting, use_counts_now)}
  end

  def begin_retreat(state) do
    {Coordinate.new(:<, state.last_nesting), state}
  end

  def turn_deeper(%{last_nesting: last_nesting, use_counts: use_counts}) do
    this_level = length(last_nesting)-1
    this_nesting = [ use_counts[this_level] | tl(last_nesting) ]
    use_counts_now = Map.update!(use_counts, this_level, & &1+1)

    {Coordinate.new(:>, this_nesting), new(this_nesting, use_counts_now)}
  end


#    field :action, :continue_deeper | :begin_retreat | :continue_retreat | :turn_deeper

end
