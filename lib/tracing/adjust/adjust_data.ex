alias Lens2.Tracing
alias Tracing.Adjust


defmodule Adjust.Data do
  import TypedStruct
  use Lens2

  typedstruct enforce: true do
    field :index, non_neg_integer
    field :coordinate, Coordinate.t

    field :source, :container | :gotten | :updated
    field :action, atom

    field :string, String.t
    field :indent, non_neg_integer, default: 0
  end

  # The actions a datum may represent.
  def continue_deeper, do: :continue_deeper
  def begin_retreat, do: :begin_retreat
  def continue_retreat, do: :continue_retreat
  def turn_deeper, do: :turn_deeper

  def classify_actions(pairs) do
    alias Tracing.Adjust.Data
    for pair <- pairs do
      case pair do
        {:>, :>} -> Data.continue_deeper
        {:>, :<} -> Data.begin_retreat
        {:<, :<} -> Data.continue_retreat
        {:<, :>} -> Data.turn_deeper
      end
    end
  end

  defp put_key(coordinate_map, subject_coordinate, key, value) do
    Deeply.put(coordinate_map,
               Lens.key_path!([subject_coordinate, key]),
               value)
  end

  def put_indent(coordinate_map, subject_coordinate, value),
      do: put_key(coordinate_map, subject_coordinate, :indent, value)

  def put_string(coordinate_map, subject_coordinate, value),
      do: put_key(coordinate_map, subject_coordinate, :string, value)

end
