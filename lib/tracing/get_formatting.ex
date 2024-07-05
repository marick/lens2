alias Lens2.Tracing
import TypedStruct

defmodule Tracing.Get do
  @moduledoc false
  alias Tracing.Common

  typedstruct enforce: true  do
    field :direction,            :> | :<
    field :left_margin, integer,  default: 0
    field :indentation_source, integer, default: :uncalculated
    field :output,               String.t, default: ""  # builds over time
  end

  def new(%{direction: :>, container: value}) do
    %__MODULE__{direction: :>,
                output: Common.stringify(value),}
  end

  def new(%{direction: :<, gotten: value}) do
    %__MODULE__{direction: :<,
                output: Common.stringify(value)}
  end
end


defmodule Tracing.Get.Indentation do
  @moduledoc false
    alias Tracing.Get

  def step1_init(lines) do
    for {line_value, line_index} <- Enum.with_index(lines), into: %{} do
      {line_index, Get.new(line_value)}
    end
  end

  def step2_note_indentation_source(step1_map) do
    reducer = fn line_index, {building_map, sources_by_level} ->
      {source_index, sources_by_level} =
        add_indentation_source(step1_map[line_index].direction, line_index, sources_by_level)
       {put_in(building_map,
               [Access.key(line_index), Access.key(:indentation_source)],
               source_index),
        sources_by_level}
    end

    1..(map_size(step1_map)-2)
    |> Enum.reduce({step1_map, [0]}, reducer)
    |> elem(0)
  end

  def add_indentation_source(:>, line_index, sources_by_level) do
    { hd(sources_by_level), [line_index | sources_by_level]}
  end

  def add_indentation_source(:<, _line_index,  [deepest | remaining_sources]) do
    { deepest, remaining_sources }
  end
end
