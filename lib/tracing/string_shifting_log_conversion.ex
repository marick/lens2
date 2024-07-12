alias Lens2.Tracing
alias Tracing.{StringShifting,Coordinate,Common}

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
