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




defmodule Tracing.CoordinateList do
  alias Tracing.Coordinate
  alias Tracing.CoordinateList.State

  def from_log([head | _rest] = log) when is_map(head),
      do: from_direction_pairs(direction_pairs(log))

  def from_direction_pairs(direction_pairs) do
    state = State.initial()
    [ Coordinate.new(:>, state.last_nesting) | produce_coordinates(direction_pairs, state) ]
  end

  def direction_pairs(log) do
    directions = Enum.map(log, & &1.direction)
    Enum.zip(directions, tl(directions))
  end

  # Private

  defmodule State do
    typedstruct enforce: true do
      field :last_nesting, [non_neg_integer], default: [0]
      field :use_counts, %{non_neg_integer => non_neg_integer}, default: %{0 => 1}
    end

    def initial, do: %__MODULE__{}

    def next(last_nesting, use_counts) do
      %__MODULE__{last_nesting: last_nesting, use_counts: use_counts}
    end
  end

  defp produce_coordinates([], _state), do: []

  defp produce_coordinates([pair | rest], state) do
    {coordinate, next_state} =
      case pair do
        {:>, :>} -> continue_deeper(state)
        {:>, :<} -> begin_retreat(state)
        {:<, :<} -> continue_retreat(state)
        {:<, :>} -> turn_deeper(state)
      end
    [ coordinate | produce_coordinates(rest, next_state) ]
  end


  defp continue_deeper(%{last_nesting: last_nesting, use_counts: use_counts}) do
    this_level = length(last_nesting)
    this_nesting = [ Map.get(use_counts, this_level, 0) | last_nesting]
    use_counts_now = Map.update(use_counts, this_level, 1, & &1 + 1)
    {Coordinate.new(:>, this_nesting), State.next(this_nesting, use_counts_now)}
  end

  defp begin_retreat(state) do
    {Coordinate.new(:<, state.last_nesting), state}
  end

  defp continue_retreat(state) do
    this_nesting = tl(state.last_nesting)
    { Coordinate.new(:<, this_nesting), %{state | last_nesting: this_nesting} }
  end

  defp turn_deeper(%{last_nesting: last_nesting, use_counts: use_counts}) do
    this_level = length(last_nesting)-1
    this_nesting = [ use_counts[this_level] | tl(last_nesting) ]
    use_counts_now = Map.update!(use_counts, this_level, & &1+1)

    {Coordinate.new(:>, this_nesting), State.next(this_nesting, use_counts_now)}
  end

end
