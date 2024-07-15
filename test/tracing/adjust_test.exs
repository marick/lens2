alias Lens2.Tracing
alias Tracing.Adjust

defmodule Tracing.AdjustTest do
  use Lens2.Case
  import Lens2.TestLogs

  describe "shifting" do
    test "trivial case" do
      input = [deeper(%{a: 1}),
               retreat([1])]
      actual = Adjust.gotten_strings(input)
      expected = ["%{a: 1}",
                  "   [1]"]
      assert actual == expected
    end

    test "just in and out" do
      input = [deeper([%{a: 1}]),
               deeper( %{a: 1}),
               retreat(   [1]),
               retreat([1])]
      actual = Adjust.gotten_strings(input)
      expected = ["[%{a: 1}]",
                  " %{a: 1}",
                   "    [1]",
                   "    [1]"

      ]
      assert actual == expected
    end

    test "intermediate levels in retreat" do
      input = [deeper(%{b: [%{a: 1}]}),
               deeper(     [%{a: 1}]),
               deeper(      %{a: 1}),
               retreat(        [1]),
               retreat(       [[1]]),
               retreat(        [1])]
      actual = Adjust.gotten_strings(input)
      expected = ["%{b: [%{a: 1}]}",
                  "     [%{a: 1}]",
                  "      %{a: 1}",
                  "         [1]",
                  "",
                  "         [1]"

      ]
      assert actual == expected
    end

    @tag :skip
    test "two descents" do
      input = [deeper(%{b: [%{a: 1, b: 2}]}),
               deeper(     [%{a: 1, b: 2}]),
               deeper(      %{a: 1, b: 2}),
               retreat(        [1]),
               deeper(      %{a: 1, b: 2}),
               retreat(              [2]),
               retreat(        [1,    2]),
      ]
      actual = Adjust.gotten_strings(input)
      expected = ["%{b: [%{a: 1, b: 2}]}",
                  "     [%{a: 1, b: 2}]",
                  "      %{a: 1, b: 2}",
                  "         [1]",
                  "      %{a: 1, b: 2}",
                  "",
                  "               [2]",
                  "         [1,    2]"

      ]
      assert actual == expected
    end

  end
end
