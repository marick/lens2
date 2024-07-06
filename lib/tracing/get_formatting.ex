alias Lens2.Tracing.{Get,Common}
import TypedStruct

defmodule Get.Nesting do
  # Note that nesting should be read from right to left, as it acts as a stack

  @type t :: [non_neg_integer]

  def original, do: [0]

  def continue_deeper(nesting) do
    [0 | nesting]
  end
end

defmodule Get.AsSource do
  typedstruct enforce: true do
    field :indent, non_neg_integer
    field :unindented, String.t
    field :try_next_at, non_neg_integer, default: 0
  end
end

defmodule Get.Line do
  typedstruct enforce: true do
    field :order, non_neg_integer
    field :nesting, Get.Nesting.t
    field :direction, :< | :>
    field :value, any
    field :string, String.t
    field :indent, non_neg_integer
  end
end


defmodule Get.Worker do
  alias Get.{Nesting, Line}
  use Lens2

  typedstruct enforce: true do
    field :nesting_to_line, %{Nesting.t => Line.t}
    field :nesting_to_source, %{Nesting.t => AsSource.t}
    field :gotten, [Nesting.t]
  end

  def_composed_maker line_for(nesting), do: Lens.key!(:nesting_to_line) |> Lens.key(nesting)
  def_composed_maker source_for(nesting), do: Lens.key!(:nesting_to_source) |> Lens.key(nesting)


  def new(%{container: value}) do
    line0 =
      struct(Get.Line,
             order: 0, direction: :>,
             value: value, string: Common.stringify(value),
             nesting: Nesting.original,
             indent: 0)
    worker =
      struct(__MODULE__,
             nesting_to_line: %{line0.nesting => line0},
             nesting_to_source: %{},
             gotten: [])
    {line0, worker}
  end

  def add(working, log_line, after: previous_line) do
    add(working, previous_line.direction, previous_line, log_line.direction, log_line)
  end

  def add(working, :>, previous_line, :>, %{container: value}) do
    nesting = Nesting.continue_deeper(previous_line.nesting)
    nil = Deeply.get_only(working, line_for(nesting)) # precondition

    line = struct(Get.Line,
                  order: previous_line.order + 1,
                  direction: :>,
                  value: value,
                  string: Common.stringify(value),
                  nesting: nesting,
                  indent: 0)
    new_working = Deeply.put(working, line_for(nesting), line)
    {line, new_working}
  end


end



# defmodule Tracing.Get.Line do
#   @moduledoc false
#   alias Tracing.Common

#   typedstruct enforce: true  do
#     field :order, non_neg_integer
#     field :direction,            :> | :<
#     field :value, any
#     field :string_value, String.t
#     field :try_match_at, non_neg_integer, 0
#     field :left_margin, non_neg_integer,  default: 0

#     field :indent_using, , default: :uncalculated
#     field :output,               String.t, default: ""  # builds over time
#   end

#   def new(%{direction: :>, container: value}) do
#     %__MODULE__{direction: :>,
#                 output: Common.stringify(value),}
#   end

#   def new(%{direction: :<, gotten: value}) do
#     %__MODULE__{direction: :<,
#                 output: Common.stringify(value)}
#   end
# end

# defmodule Tracing.Get.Lines do
#   @moduledoc false

#   type nesting_index :: [integer]


#   typedstruct enforce: true  do
#     field :nesting_index_to_line, %{nesting_index => Get.Line.t}, default: %{}
#     field :result_indices, [nesting_index], default: []
#   end
# end


# defmodule Tracing.Get.Indentation do
#   @moduledoc false
#     alias Tracing.Get

#   def step1_init(lines) do
#     for {line_value, line_index} <- Enum.with_index(lines), into: %{} do
#       {line_index, Get.new(line_value)}
#     end
#   end

#   def step2_note_indentation_source(step1_map) do
#     reducer = fn line_index, {building_map, sources_by_level} ->
#       {source_index, sources_by_level} =
#         add_indentation_source(step1_map[line_index].direction, line_index, sources_by_level)
#        {put_in(building_map,
#                [Access.key(line_index), Access.key(:indentation_source)],
#                source_index),
#         sources_by_level}
#     end

#     1..(map_size(step1_map)-2)
#     |> Enum.reduce({step1_map, [0]}, reducer)
#     |> elem(0)
#   end

#   def add_indentation_source(:>, line_index, sources_by_level) do
#     { hd(sources_by_level), [line_index | sources_by_level]}
#   end

#   def add_indentation_source(:<, _line_index,  [deepest | remaining_sources]) do
#     { deepest, remaining_sources }
#   end
# end
