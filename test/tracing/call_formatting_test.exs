alias Lens2.Tracing

defmodule Tracing.CallTest do
  use Lens2.Case
  alias Tracing.Call
  import FlowAssertions.TabularA

  describe "the argument list" do
    test "portraying the complete argument list" do
      returns = run_and_assert(& Call.new(:>, :lens, &1) |> Call.args_string)

      [] |> returns.("")
      [:a] |> returns.("(:a)")
      [8, 12] |> returns.("(8, 12)")
    end

    test "shortening a function argument" do
      fun_arg = Call.new(:>, :lens, [5, Lens.at(:a)])
      assert Call.args_string(fun_arg) == "(5, <fn>)"
    end
  end

  describe "the whole call" do
    test "simple cases" do
      going_in = Call.new(:>, :lens, [:a])
      coming_out = %{going_in | direction: :<}
      assert Call.call_string(going_in) == ">lens(:a)"
      assert Call.call_string(coming_out) == "<lens(:a)"
    end
  end
end

defmodule Tracing.CallsTest do
  use Lens2.Case
  alias Tracing.Calls
  alias Tracing.Call

  test "creating " do
    input = [
      %{direction: :>, name: :key, args: []},
      %{direction: :<, name: :key, args: []}
    ]

    actual = Calls.from(input)
    expected = [
      Call.new(:>, :key, []),
      Call.new(:<, :key, [])
    ]

    assert actual == expected
  end

  def suitable_map(direction, name, args),
      do: %{direction: direction, name: name, args: args}

  describe "creating the call strings" do
    test "simple case" do

      input = [
        suitable_map(:>, :key, [:a]),
        suitable_map(:>, :keys, [[:a, :b]]),
        suitable_map(:<, :keys, [[:a, :b]]),
        suitable_map(:<, :key, [:a])
      ]

      actual = input |> Calls.from |> Calls.format_calls

      assert Calls.strings(actual) ==
               [ ">key(:a)",
                 ">keys([:a, :b])",
                 "<keys([:a, :b])",
                 "<key(:a)"
               ]
    end
  end

  describe "calculating indent before" do
    test "trivial" do
      input =
        [
          Call.new(:>, :key, [:a]),
          Call.new(:<, :key, [:a])
        ]
        |> Calls.format_calls

      expected =
        [ ">key(:a)",
          "<key(:a)"
        ]

      actual = Calls.add_indents(input)
      assert Calls.strings(actual) == expected
    end

    test "nesting" do
      input = [
        Call.new(:>, :key, [:a]),
        Call.new(:>, :keys, [[:a, :b]]),
        Call.new(:<, :keys, [[:a, :b]]),
        Call.new(:<, :key, [:a])
      ] |> Calls.format_calls

      expected =
        [ ">key(:a)",
          "   >keys([:a, :b])",
          "   <keys([:a, :b])",
          "<key(:a)"
        ]
      actual = Calls.add_indents(input)
      assert Calls.strings(actual) == expected
    end
  end

  test "what is the longest string?" do
    input = [
      %{string: ">key(:a)"},
      %{string: ">  >key(:b)"},
      %{string: ">     >keys([:c, :d])"}
      #          123456789012345678901
    ]

    assert Calls.max_width(input) == 21
  end

  test "padding on the right" do
    input =
      [
        Call.new(:>, :key, [:a]),
        Call.new(:>, :keys, [[:a, :b]]),
        Call.new(:<, :keys, [[:a, :b]]),
        Call.new(:<, :key, [:a])
      ]
      |> Calls.format_calls
      |> Calls.add_indents

    expected =
      [ ">key(:a)          ",
        "   >keys([:a, :b])",
        "   <keys([:a, :b])",
        "<key(:a)          "
      ]

    actual =
      Calls.pad_to_flush_right(input)

    assert Calls.strings(actual) == expected
  end


  test "normally done as a single function call" do
    input =
      [
        suitable_map(:>, :key, [:a]),
        suitable_map(:>, :keys, [[:a, :b]]),
        suitable_map(:<, :keys, [[:a, :b]]),
        suitable_map(:<, :key, [:a])
      ]

    expected =
      [ ">key(:a)          ",
        "   >keys([:a, :b])",
        "   <keys([:a, :b])",
        "<key(:a)          "
      ]

    assert Calls.log_to_call_strings(input) == expected
  end

end
