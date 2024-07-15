alias Lens2.Tracing
alias Tracing.Adjust

defmodule Adjust do
  alias Tracing.Coordinate
  alias Adjust.{Preparation,One,Many}

  # The two-element case is special
  def gotten_strings(log) do
    {coordinate_list, coordinate_map} = Preparation.prepare_aggregates(log, pick_result: :gotten)
    line_count = length(coordinate_list)

    new_coordinate_map =
      if line_count == 2 do
        plan = One.plan_for(coordinate_map[Coordinate.final_retreat])
        One.adjust(coordinate_map, Coordinate.final_retreat, plan)
      else
        Enum.slice(coordinate_list, 1..line_count-2)
        |> Many.shift_interior(coordinate_map)
        |> One.align_final_retreat()
      end
    Many.extract_strings(coordinate_list, new_coordinate_map)
  end


end
