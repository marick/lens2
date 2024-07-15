alias Lens2.Tracing
alias Tracing.Adjust


defmodule Adjust.Many do
  alias Adjust.One

  def shift_interior(interior_coordinates, coordinate_map) do
    reducer = fn subject_coordinate, changing_coordinate_map ->
      plan = One.plan_for(changing_coordinate_map[subject_coordinate])
      One.adjust(changing_coordinate_map, subject_coordinate, plan)
    end
    Enum.reduce(interior_coordinates, coordinate_map, reducer)
  end

  def extract_strings(coordinate_list, coordinate_map) do
    for coord <- coordinate_list do
      shift_data = coordinate_map[coord]
      padding(shift_data.indent) <> shift_data.string
    end
  end

  defp padding(n), do: String.duplicate(" ", n)
end
