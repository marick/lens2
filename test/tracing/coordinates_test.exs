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

    test "continuing downward" do
      input = [:>,
                 :>,
                   :>,
                   :<,
                 :<,
               :<,
      ]

      actual = Maker.from(flabby(input))
      assert actual === [
               Coordinate.new(:>,           [0]),
               Coordinate.new(  :>,      [0, 0]),
               Coordinate.new(    :>, [0, 0, 0]),
               Coordinate.new(    :<, [0, 0, 0]),
               Coordinate.new(  :<,      [0, 0]),
               Coordinate.new(:<,           [0]),
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
               Coordinate.new(:>,                      [0]),
               Coordinate.new(  :>,                 [0, 0]),
               Coordinate.new(    :>,            [0, 0, 0]),
               Coordinate.new(    :<,            [0, 0, 0]),
               Coordinate.new(    :>,            [1, 0, 0]),

               Coordinate.new(      :>,       [0, 1, 0, 0]),
               Coordinate.new(         :>, [0, 0, 1, 0, 0]),
             ]
    end

    test "multiple excursions upward through a level" do
      input = [:>,
                 :>,
                   :>,
                     :>,
                     :<,
                   :<,

                   :>,
                     :>,
                     :<,
                   :<,
                 :<,

                 :>,
                   :>,
                     :>,
                     :<,
                   :<,

                   :>,
                     :>,
                     :<,
                   :<,
                 :<,
               :<
      ]

      actual = Maker.from(flabby(input))
      assert actual === [
               Coordinate.new(:>,                   [0]),    # 0 => 1
               Coordinate.new(  :>,              [0, 0]),    # +  1 => 1
               Coordinate.new(    :>,         [0, 0, 0]),    # +     2 => 1
               Coordinate.new(      :>,    [0, 0, 0, 0]),    # +       3 => 1
               Coordinate.new(      :<,    [0, 0, 0, 0]),    #
               Coordinate.new(    :<,         [0, 0, 0]),    #

               Coordinate.new(    :>,         [1, 0, 0]),    #       2 => 2
               Coordinate.new(      :>,    [1, 1, 0, 0]),    #         3 => 2
               Coordinate.new(      :<,    [1, 1, 0, 0]),    #
               Coordinate.new(    :<,         [1, 0, 0]),    #
               Coordinate.new(  :<,              [0, 0]),    #

               Coordinate.new(  :>,              [1, 0]),    #    1 => 2
               Coordinate.new(    :>,         [2, 1, 0]),    #       2 => 3
               Coordinate.new(      :>,    [2, 2, 1, 0]),    #         3 => 3
               Coordinate.new(      :<,    [2, 2, 1, 0]),    #
               Coordinate.new(    :<,         [2, 1, 0]),    #

               Coordinate.new(    :>,         [3, 1, 0]),    #      2 => 4
               Coordinate.new(      :>,    [3, 3, 1, 0]),    #        3 => 4
               Coordinate.new(      :<,    [3, 3, 1, 0]),    #
               Coordinate.new(    :<,         [3, 1, 0]),
               Coordinate.new(  :<,              [1, 0]),
               Coordinate.new(:<,                   [0]),
             ]
    end

  end
end
