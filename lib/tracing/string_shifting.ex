alias Lens2.Tracing
alias Tracing.{StringShifting,Coordinate,Common}

# The Data type is essentially a Protocol, but I didn't want to cons up
# three identical structures, so the dispatch will be done manually.
# Kind of like GenServer.
#
# defprotocol with a poor man's version of Haskell's  "phantom type" may be better.
defmodule StringShifting.ShiftData do
  import TypedStruct

  typedstruct enforce: true do
    field :index, non_neg_integer
    field :coordinate, Coordinate.t

    field :source, :container | :gotten | :updated
    field :action, atom

    field :string, String.t
    field :indent, non_neg_integer, default: 0
  end

  def describe_adjustment(%{source: :container, action: :continue_deeper} = line) do
    [align_under_substring: Coordinate.un_nest(line.coordinate)]
  end

  def describe_adjustment(%{source: :container, action: :turn_deeper} = line) do
    [copy: Coordinate.previous(line.coordinate)]
  end

  def describe_adjustment(%{source: :gotten, action: :begin_retreat} = line) do
    [center_under: Coordinate.reverse_direction(line.coordinate)]
  end

  def describe_adjustment(%{source: :gotten, action: :continue_retreat}) do
    :erase
  end
end





defmodule StringShifting.Adjuster do
  use Lens2
  import Lens2.Helpers.Assert

  def adjust(by_coordinate, subject_coordinate, align_under_substring: guidance_coordinate) do
    {subject, guidance} =
      {by_coordinate[subject_coordinate], by_coordinate[guidance_coordinate]}

    assert(guidance.action == Coordinate.continue_deeper)

    [prefix, _] = String.split(guidance.string, subject.string, parts: 2)

    # Note: Regex.split(return: :index) counts *bytes*, not characters.

    Deeply.put(by_coordinate,
               Lens.key_path!([subject_coordinate, :indent]),
               guidance.indent + String.length(prefix))
  end

  def adjust(by_coordinate, subject_coordinate, center_under: guidance_coordinate) do
    guidance = by_coordinate[guidance_coordinate]
    half = String.length(guidance.string) |> div(2)
    Deeply.put(by_coordinate,
               Lens.key_path!([subject_coordinate, :indent]),
               guidance.indent + half)

  end



end
defmodule StringShifting.LogLines do
  defmodule LogLine do
    def value_from(%{container: value}, _), do: value
    def value_from(%{gotten: value}, :gotten), do: value
    def value_from(%{updated: value}, :updated), do: value

    def source(:>, _),        do: :container
    def source(:<, :gotten),  do: :gotten
    def source(:<, :updated), do: :updated
  end

  alias StringShifting.ShiftData

  def condense(displaying, log) do
    values = convert_to_shift_data(displaying, log)
    map = for value <- values, into: %{}, do: {value.coordinate, value}
    in_order = for value <- values, do: value.coordinate

    {in_order, map}
  end

  def convert_to_shift_data(displaying, log) do
    {coordinates, actions} = coordinates_and_actions(log)
    strings = strings(log, source: displaying)

    data = Enum.zip([0..length(log)-1, coordinates, strings, actions])
    for {index, coordinate, string, action} <- data do
      %ShiftData{source: LogLine.source(coordinate.direction, displaying),
                 index: index,
                 coordinate: coordinate,
                 string: string,
                 action: action}
    end
  end

  defp coordinates_and_actions(log) do
    refined = Coordinate.Maker.refine(log)
    coordinates = Coordinate.Maker.from(refined)
    actions = [:no_previous_direction | Coordinate.Maker.classify_actions(refined)]
    {coordinates, actions}
  end

  defp strings(log, source: source) do
    for line <- log, do: LogLine.value_from(line, source) |> Common.stringify
  end


end
