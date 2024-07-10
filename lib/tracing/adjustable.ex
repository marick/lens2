alias Lens2.Tracing
alias Tracing.{Adjustable,Coordinate,Common}


# The Data type is essentially a Protocol, but I didn't want to cons up
# three identical structures, so the dispatch will be done manually.
# Kind of like GenServer.
#
# defprotocol with a poor man's version of Haskell's  "phantom type" may be better.
defmodule Adjustable.Data do
  alias Adjustable.{ContainerLine, GottenLine}
  import TypedStruct

  typedstruct enforce: true do
    field :type, atom
    field :index, non_neg_integer
    field :coordinate, Coordinate.t
    field :action, atom
    field :string, String.t
    field :indent, non_neg_integer, default: 0
    field :start_search_at, non_neg_integer, default: 0
  end

  def describe_adjustment(%{type: ContainerLine, action: :continue_deeper} = line) do
    [align_with_substring: Coordinate.un_nest(line.coordinate)]
  end

  def describe_adjustment(%{type: ContainerLine, action: :turn_deeper} = line) do
    [copy: Coordinate.previous(line.coordinate)]
  end

  def describe_adjustment(%{type: GottenLine, action: :begin_retreat} = line) do
    [center_under: Coordinate.reverse_direction(line.coordinate)]
  end

  def describe_adjustment(%{type: GottenLine, action: :continue_retreat}) do
    :erase
  end





end

defmodule Adjustable.ContainerLine do
end

defmodule Adjustable.GottenLine do
end

defmodule Adjustable.UpdatedLine do
end

defmodule Adjustable.Maker do

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
      %Adjustable.Data{type: type(coordinate.direction, retreat_key),
                       index: index,
                       coordinate: coordinate,
                       string: string,
                       action: action}
    end
  end

  defp value(%{container: value}, _), do: value
  defp value(%{gotten: value}, :gotten), do: value
  defp value(%{updated: value}, :updated), do: value

  defp type(:>, _),        do: Adjustable.ContainerLine
  defp type(:<, :gotten),  do: Adjustable.GottenLine
  defp type(:<, :updated), do: Adjustable.UpdatedLine

  defp coordinates_and_actions(log) do
    refined = Coordinate.Maker.refine(log)
    coordinates = Coordinate.Maker.from(refined)
    actions = [:no_previous_direction | Coordinate.Maker.classify_actions(refined)]
    {coordinates, actions}
  end
end

defmodule Adjustable.Adjuster do

end
