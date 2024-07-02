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

  describe "creating the call strings" do
    test "simple case" do

      input = [
        Call.new(:>, :key, [:a]),
        Call.new(:>, :keys, [[:a, :b]]),
        Call.new(:<, :keys, [[:a, :b]]),
        Call.new(:<, :key, [:a])
      ]

      actual = Calls.add_call_strings(input)

      assert Calls.call_strings(actual) ==
               [ ">key(:a)",
                 ">keys([:a, :b])",
                 "<keys([:a, :b])",
                 "<key(:a)"
               ]
    end
  end

  describe "calculating indent before" do
    test "trivial" do
      input = [
        Call.new(:>, :key, [:a]),
        Call.new(:<, :key, [:a])
      ]

      actual = Calls.add_indents(input)
      assert Calls.indents(actual) == [0, 0]
    end

    test "nesting" do
      input = [
        Call.new(:>, :key, [:a]),
        Call.new(:>, :keys, [[:a, :b]]),
        Call.new(:<, :keys, [[:a, :b]]),
        Call.new(:<, :key, [:a])
      ]

      actual = Calls.add_indents(input)

      assert Calls.indents(actual) == [0, 3, 3, 0]
    end



  end
end
