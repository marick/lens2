alias Lens2.Tracing
alias Tracing.{StringShifting,Coordinate}

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
