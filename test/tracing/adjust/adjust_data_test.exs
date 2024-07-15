alias Lens2.Tracing
alias Tracing.Adjust

defmodule Adjust.DataTest do
  use Lens2.Case
  alias Tracing.CoordinateList

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


  def loglike(directions), do: Enum.map(directions, & %{direction: &1})

  test "classifying actions" do
    alias Adjust.Data, as: D
    actual =
      loglike(@multiple_turns)
      |> CoordinateList.direction_pairs
      |> D.classify_actions

      assert actual == [
               # :>,        not represented
               #   :>,
                   D.continue_deeper,
               #     :>,
                     D.continue_deeper,
               #       :>,
                       D.continue_deeper,
               #       :<,
                       D.begin_retreat,
               #     :<,
                     D.continue_retreat,

               #     :>,
                     D.turn_deeper,
               #       :>,
                       D.continue_deeper,
               #       :<,
                       D.begin_retreat,
               #     :<,
                     D.continue_retreat,
               #   :<,
                   D.continue_retreat,

               #   :>,
                   D.turn_deeper,
               #     :>,
                     D.continue_deeper,
               #       :>,
                       D.continue_deeper,
               #       :<,
                       D.begin_retreat,
               #     :<,
                     D.continue_retreat,

               #     :>,
                     D.turn_deeper,
               #       :>,
                     D.continue_deeper,
               #       :<,
                       D.begin_retreat,
               #     :<,
                     D.continue_retreat,
               #   :<,
                   D.continue_retreat,
               # :<,
                 D.continue_retreat,
         ]
  end
end
