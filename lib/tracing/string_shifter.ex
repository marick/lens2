alias Lens2.Tracing
alias Tracing.{StringShift,Coordinate,Common}


# The Value type is essentially a Protocol, but I didn't want to cons up
# three identical structures, so the dispatch will be done manually.
# Kind of like GenServer.
#
# defprotocol with a poor man's version of Haskell's  "phantom type" may be better.
defmodule StringShift.Value do
  import TypedStruct

  typedstruct enforce: true do
    field :index, non_neg_integer
    field :coordinate, Coordinate.t

    field :string, String.t
    field :source, :container | :gotten | :updated

    field :action, atom
    field :indent, non_neg_integer, default: 0
    field :start_search_at, non_neg_integer, default: 0
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


defmodule StringShift.Maker do

  def condense(retreat_key, log) do
    values = make_map_values(retreat_key, log)
    map = for value <- values, into: %{}, do: {value.coordinate, value}
    in_order = for value <- values, do: value.coordinate

    {in_order, map}
  end

  def make_map_values(retreat_key, log) do
    {coordinates, actions} = coordinates_and_actions(log)
    strings = for line <- log, do: value(line, retreat_key) |> Common.stringify

    data = Enum.zip([0..length(log)-1, coordinates, strings, actions])
    for {index, coordinate, string, action} <- data do
      %StringShift.Value{source: source(coordinate.direction, retreat_key),
                       index: index,
                       coordinate: coordinate,
                       string: string,
                       action: action}
    end
  end

  defp value(%{container: value}, _), do: value
  defp value(%{gotten: value}, :gotten), do: value
  defp value(%{updated: value}, :updated), do: value

  defp source(:>, _),        do: :container
  defp source(:<, :gotten),  do: :gotten
  defp source(:<, :updated), do: :updated

  defp coordinates_and_actions(log) do
    refined = Coordinate.Maker.refine(log)
    coordinates = Coordinate.Maker.from(refined)
    actions = [:no_previous_direction | Coordinate.Maker.classify_actions(refined)]
    {coordinates, actions}
  end
end

defmodule StringShift.Adjuster do
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
