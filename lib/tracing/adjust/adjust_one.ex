alias Lens2.Tracing
alias Tracing.Adjust

defmodule Adjust.One do
  use Lens2
  import Lens2.Helpers.Assert
  alias Tracing.Coordinate
  alias Adjust.Data

  def plan_for(shift_data) do
    coordinate = shift_data.coordinate

    case {shift_data.source, shift_data.action} do
      {:container, :continue_deeper} ->
        [align_under_substring: Coordinate.un_nest(coordinate)]
      {:container, :turn_deeper} ->
        [copy: Coordinate.previous(coordinate)]
      {:gotten, :begin_retreat} ->
        [center_under: Coordinate.reverse_direction(coordinate)]
      {:gotten, :continue_retreat} ->
        :make_invisible
    end
  end

  #-

  def adjust(coordinate_map, subject_coordinate, align_under_substring: guidance_coordinate) do
    {subject, guidance} =
      {coordinate_map[subject_coordinate], coordinate_map[guidance_coordinate]}

    assert(guidance.action == Adjust.Data.continue_deeper)

    # Note: Regex.split(return: :index) counts *bytes*, not characters.
    [prefix, _] = String.split(guidance.string, subject.string, parts: 2)

    Data.put_indent(coordinate_map, subject_coordinate,
                    guidance.indent + String.length(prefix))
  end

  def adjust(coordinate_map, subject_coordinate, center_under: guidance_coordinate) do
    guidance = coordinate_map[guidance_coordinate]
    half = String.length(guidance.string) |> div(2)
    Data.put_indent(coordinate_map, subject_coordinate,
                    guidance.indent + half)
  end

  def adjust(coordinate_map, subject_coordinate, :make_invisible),
      do: Data.put_string(coordinate_map, subject_coordinate, "")

  #-

  def align_final_retreat(by_coordinate) do
    result_in_order =
      by_coordinate
      |> Map.values
      |> Enum.filter(& &1.action == Adjust.Data.begin_retreat)
      |> Enum.reject(& &1.coordinate == Coordinate.final_retreat)

    case result_in_order do
      [only] ->
        Deeply.put(by_coordinate,
                   Lens.key_path!([Coordinate.final_retreat, :indent]),
                   only.indent)
    end
  end
end
