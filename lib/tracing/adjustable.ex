alias Lens2.Tracing
alias Tracing.{Adjustable,Coordinate,Common}
import TypedStruct

defmodule Adjustable.ContainerLine do
  typedstruct enforce: true do
    field :string, String.t
    field :index, non_neg_integer
    field :coordinate, Coordinate.t
    field :action, atom
  end
end

defmodule Adjustable.GottenLine do
  typedstruct enforce: true do
    field :string, String.t
    field :index, non_neg_integer
    field :coordinate, Coordinate.t
    field :action, atom
  end
end

defmodule Adjustable.Maker do
#  alias Adjustable.{ContainerLine, GottenLine}

  def make_map_values(retreat_key, log) do
    {coordinates, actions} = coordinates_and_actions(log)
    strings = for line <- log, do: value(line, retreat_key) |> Common.stringify

    data = Enum.zip([0..length(log)-1, coordinates, strings, actions])
    for {index, coordinate, string, action} <- data do
      %{coordinate: coordinate,
        string: string,
        index: index,
        action: action}
    end
  end

  defp value(%{container: value}, _), do: value
  defp value(%{gotten: value}, :gotten), do: value
  defp value(%{updated: value}, :updated), do: value

  defp coordinates_and_actions(log) do
    refined = Coordinate.Maker.refine(log)
    coordinates = Coordinate.Maker.from(refined)
    actions = [:no_previous_direction | Coordinate.Maker.classify_actions(refined)]
    {coordinates, actions}
  end


  def make_map(_result_key, [_log_hd | _log_tl]) do
    # entry_line = Adjustable.ContainerLine.new({log_hd, 0, Coordinate.new(:>, [0]),
    #                                            Coordinate.continue_deeper})
    # [entry_line, 1]
    # {coordinates, actions} =
  end

  def make_lines(_result_key, _log_tail) do
    # indices = 1..length(log_tail)
    # just_directions = Maker.refine(raw_log) |> dbg
    # coordinates = Maker.from(just_directions) |> dbg
    # actions = Maker.classify_actions(just_directions) |> dbg

    # for {log_line, _, _, _} = tuple <- Enum.zip([raw_log, indices, coordinates, actions]) do
    #   case {Map.has_key?(log_line, :container), result_key} do
    #     {true, _} -> Adjustable.ContainerLine.new(tuple)
    #     {false, :gotten} -> Adjustable.GottenLine.new(tuple)
    #   end
    # end
  end


end
