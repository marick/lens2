defmodule Lens2.Tracing.MutableTest do
  use Lens2.Case
  alias Lens2.Helpers.Tracing
  alias Tracing.{EntryLine,ExitLine}
  alias Tracing.Mutable


  test "lifecycle" do
    container = [[[1, 2], [3, 4]]]

    assert Mutable.empty_stack?

    Mutable.add_log_item(EntryLine.new(:at, [0], container))
    expected1_in = %EntryLine{call: "at(0)", container: inspect(container)}
    assert Mutable.peek_at_log(at: -1) == expected1_in
    refute Mutable.empty_stack?

      Mutable.add_log_item(EntryLine.new(:all, [], [[1, 2], [3, 4]]))
      expected1_1_in = %EntryLine{call: "all()", container: inspect [[1, 2], [3, 4]]}
      assert Mutable.peek_at_log(at: -1) == expected1_1_in

        Mutable.add_log_item(EntryLine.new(:at, [1], [1, 2]))
        expected1_1_1_in = %EntryLine{call: "at(1)", container: inspect [1, 2]}
        assert Mutable.peek_at_log(at: -1) == expected1_1_1_in

        Mutable.add_log_item(ExitLine.new(:at, [1], [2], [1, 222]))
        expected1_1_1_out = %ExitLine{call: "at(1)", gotten: "[2]", updated: "[1, 222]"}
        assert Mutable.peek_at_log(at: -1) == expected1_1_1_out
        refute Mutable.empty_stack?

        Mutable.add_log_item(EntryLine.new(:at, [1], [3, 4]))
        expected1_1_2_in = %EntryLine{call: "at(1)", container: inspect [3, 4]}
        assert Mutable.peek_at_log(at: -1) == expected1_1_2_in

        Mutable.add_log_item(ExitLine.new(:at, [1], [4], [3, 444]))
        expected1_1_2_out = %ExitLine{call: "at(1)", gotten: "[4]", updated: "[3, 444]"}
        assert Mutable.peek_at_log(at: -1) == expected1_1_2_out
        refute Mutable.empty_stack?

      Mutable.add_log_item(ExitLine.new(:all, [], :gotten1_1, :updated1_2))
      expected1_1_out = %ExitLine{call: "all()", gotten: ":gotten1_1", updated: ":updated1_2"}
      assert Mutable.peek_at_log(at: -1) == expected1_1_out
      refute Mutable.empty_stack?

    Mutable.add_log_item(ExitLine.new(:all, [], :gotten1, :updated1))
    expected1_out = %ExitLine{call: "all()", gotten: ":gotten1", updated: ":updated1"}
    assert Mutable.peek_at_log(at: -1) == expected1_out
    assert Mutable.empty_stack?

    log = Mutable.peek_at_log()
    assert length(log) == 8
    assert Enum.at(log, 0) == expected1_in
    assert Enum.at(log, 7) == expected1_out

    assert Mutable.forget_log
    assert Mutable.peek_at_log == []
  end
end
