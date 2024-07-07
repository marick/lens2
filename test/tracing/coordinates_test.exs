alias Lens2.Tracing

defmodule Tracing.CoordinatesTest do
  use Lens2.Case
  alias Tracing.Coordinate
  alias Tracing.Coordinate.Maker

  test "construction of input from maps" do
    flabby = [
      %{direction: :>},        # 0
      %{direction:   :>},      # 1
      %{direction:     :>},    # 2
      %{direction:       :>},  # 3
      %{direction:       :<},  # 4
      %{direction:     :<},    # 5
      %{direction:     :>},    # 6
      %{direction:       :>},  # 7
      %{direction:       :<},  # 8
      %{direction:     :<},    # 9
      %{direction:   :<},      # 10
      %{direction: :<},        # 11
    ]

    actual = Maker.refine(flabby)

    assert actual == [
             {:>, :>},              # 0, 1
             {:>, :>},              # 1, 2
             {:>, :>},              # 2, 3
             {:>, :<},              # 3, 4
             {:<, :<},              # 4, 5
             {:<, :>},              # 5, 6
             {:>, :>},              # 6, 7
             {:>, :<},              # 7, 8
             {:<, :<},              # 8, 9
             {:<, :<},              # 9, 10,
             {:<, :<},              # 10, 11
         ]
  end

  def flabby(directions), do: Enum.map(directions, & %{direction: &1})

  describe "calculating coordinates" do
    test "moving deeper" do
      input = [:>,
                 :>,
                   :>,
      ]

      actual = Maker.from(flabby(input))
      assert actual === [
               Coordinate.new(:>,           [0]),
               Coordinate.new(  :>,      [0, 0]),
               Coordinate.new(    :>, [0, 0, 0])
             ]
    end

    test "turning downward" do
      input = [:>,
                 :>,
                   :>,
                   :<,
      ]

      actual = Maker.from(flabby(input))
      assert actual === [
               Coordinate.new(:>,           [0]),
               Coordinate.new(  :>,      [0, 0]),
               Coordinate.new(    :>, [0, 0, 0]),
               Coordinate.new(    :<, [0, 0, 0]),
             ]
    end

    test "turning back upward, and continuing that way" do
      input = [:>,
                 :>,
                   :>,
                   :<,
                   :>,

                     :>,
                     :>,
      ]

      actual = Maker.from(flabby(input))
      assert actual === [
               Coordinate.new(:>,           [0]),
               Coordinate.new(  :>,      [0, 0]),
               Coordinate.new(    :>, [0, 0, 0]),
               Coordinate.new(    :<, [0, 0, 0]),
               Coordinate.new(    :>, [1, 0, 0]),

               Coordinate.new(    :>, [0, 1, 0, 0]),
               Coordinate.new(    :>, [0, 0, 1, 0, 0]),
             ]
    end

  end
end
