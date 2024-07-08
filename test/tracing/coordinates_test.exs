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

  test "classifying the action a pair represents" do
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

    @multiple_turns [
               :>,       # %{zzz: [%{aa: %{a: 1}, bb: %{a: 2}},   %{aa: %{a: 3}, bb: %{a: 4}}]}  key(:zzz)
                 :>,     #        [%{aa: %{a: 1}, bb: %{a: 2}},   %{aa: %{a: 3}, bb: %{a: 4}}]   at(0, 1)        1: refer to previous
                   :>,   #         %{aa: %{a: 1}, bb: %{a: 2}}                                   keys(:aa, :bb)  2: refer to previous
                     :>, #               %{a: 1}}                                                key(:a)         3: refer to previous
                     :<, #                   [1]                                                                 4: stash away
                   :<,   #

                   :>,   #         %{aa: %{a: 1}, bb: %{a: 2}}                                   keys(:aa, :bb)  6: refer to 2 [1,0,0] => [0, 0, 0]
                     :>, #                            %{a: 2}                                                    7: refer to previous
                     :<, #                                [2]                                                    8: stash away
                   :<,   #
                 :<,     #

                 :>,     #        [%{aa: %{a: 1}, bb: %{a: 2}},   %{aa: %{a: 3}, bb: %{a: 4}}]    at(0, 1)       11: refer to 1   [1, 0] => [0, 0]
                   :>,   #                                        %{aa: %{a: 3}, bb: %{a: 4}}                    12: refer to previous (but must note search position)
                     :>, #                                              %{a: 3}                                  13: refer to previous
                     :<, #                                                  [3]                                  14: stash away
                   :<,   #

                   :>,   #                                        %{aa: %{a: 3}, bb: %{a: 4}}                    16: refer to 12  [3, 1, 0] => [2, 1, 0]
                     :>, #                                                           %{a: 4}                     17: refer to previous
                     :<, #                                                               [4]                     18: stash away
                   :<,
                 :<,
               :<        #                  [1,            2                3             4]
      ]

    test "multiple excursions upward through a level" do
      actual = Maker.from(flabby(@multiple_turns))
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

    test "classifying actions" do
      alias Coordinate, as: C
      actual =
        flabby(@multiple_turns)
        |> Maker.refine
        |> Maker.classify_actions

      assert actual == [
               # :>,        not represented
               #   :>,
                   C.continue_deeper,
               #     :>,
                     C.continue_deeper,
               #       :>,
                       C.continue_deeper,
               #       :<,
                       C.begin_retreat,
               #     :<,
                     C.continue_retreat,

               #     :>,
                     C.turn_deeper,
               #       :>,
                       C.continue_deeper,
               #       :<,
                       C.begin_retreat,
               #     :<,
                     C.continue_retreat,
               #   :<,
                   C.continue_retreat,

               #   :>,
                   C.turn_deeper,
               #     :>,
                     C.continue_deeper,
               #       :>,
                       C.continue_deeper,
               #       :<,
                       C.begin_retreat,
               #     :<,
                     C.continue_retreat,

               #     :>,
                     C.turn_deeper,
               #       :>,
                     C.continue_deeper,
               #       :<,
                       C.begin_retreat,
               #     :<,
                     C.continue_retreat,
               #   :<,
                   C.continue_retreat,
               # :<,
                 C.continue_retreat,
         ]

    end


  end
end
