alias Lens2.Tracing
alias Tracing.{Adjust, Common}
alias Adjust.Preparation


defmodule Preparation.LogLine do
  def value_from(%{container: value}, _), do: value
  def value_from(%{gotten: value}, :gotten), do: value
  def value_from(%{updated: value}, :updated), do: value

  def source(:>, _),        do: :container
  def source(:<, :gotten),  do: :gotten
  def source(:<, :updated), do: :updated
end

defmodule Preparation do
  alias Preparation.{LogLine}
  alias Tracing.CoordinateList

  def prepare_aggregates(log, pick_result: result_type) do
    values = prepare_lines(log, pick_result: result_type)
    map = for value <- values, into: %{}, do: {value.coordinate, value}
    in_order = for value <- values, do: value.coordinate

    {in_order, map}
  end

  def prepare_lines(log, pick_result: result_type) do
    {coordinates, actions} = coordinates_and_actions(log)
    strings = strings(log, source: result_type)

    data = Enum.zip([0..length(log)-1, coordinates, strings, actions])
    for {index, coordinate, string, action} <- data do
      %Adjust.Data{source: LogLine.source(coordinate.direction, result_type),
                   index: index,
                   coordinate: coordinate,
                   string: string,
                   action: action}
    end
  end

  defp coordinates_and_actions(log) do
    direction_pairs = CoordinateList.direction_pairs(log)
    coordinates = CoordinateList.from_direction_pairs(direction_pairs)
    actions = [:continue_deeper | Adjust.Data.classify_actions(direction_pairs)]
    {coordinates, actions}
  end

  defp strings(log, source: source) do
    for line <- log, do: LogLine.value_from(line, source) |> Common.stringify
  end


end
