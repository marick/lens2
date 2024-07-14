alias Lens2.Tracing
alias Tracing.{StringShifting,Coordinate}

defmodule StringShifting do
  alias StringShifting.{ShiftData,Adjuster}
  alias Tracing.Adjust.Preparation
  use Lens2


  # The two-element case is special
  def gotten_strings(log) do
    {coordinate_list, coordinate_map} = Preparation.prepare_aggregates(log, pick_result: :gotten)
    line_count = length(coordinate_list)

    new_coordinate_map =
      if line_count == 2 do
        plan = ShiftData.plan_for(coordinate_map[Coordinate.final_retreat])
        Adjuster.adjust(coordinate_map, Coordinate.final_retreat, plan)
      else
        Enum.slice(coordinate_list, 1..line_count-2)
        |> shift_interior(coordinate_map)
        |> align_final_retreat()
      end
    extract_strings(coordinate_list, new_coordinate_map)

  end

  def shift_interior(shiftable, coordinate_map) do
    Enum.reduce(shiftable, coordinate_map, fn subject_coordinate, shifting_coordinate_map ->
      plan = ShiftData.plan_for(shifting_coordinate_map[subject_coordinate])
      Adjuster.adjust(shifting_coordinate_map, subject_coordinate, plan)
    end)
  end

  def align_final_retreat(by_coordinate) do
    result_in_order =
      by_coordinate
      |> Map.values
      |> Enum.filter(& &1.action == Coordinate.begin_retreat)
      |> Enum.reject(& &1.coordinate == Coordinate.final_retreat)

    case result_in_order do
      [only] ->
        Deeply.put(by_coordinate,
                   Lens.key_path!([Coordinate.final_retreat, :indent]),
                   only.indent)
    end
  end

  def extract_strings(coordinate_list, coordinate_map) do
    for coord <- coordinate_list do
      shift_data = coordinate_map[coord]
      padding(shift_data.indent) <> shift_data.string
    end
  end

  def padding(n), do: String.duplicate(" ", n)


end

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
