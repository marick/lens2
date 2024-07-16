alias Lens2.Tracing

defmodule Tracing.StateTest do
  use Lens2.Case
  alias Tracing.State
  alias State.DescentItem, as: D
  alias State.RetreatItem, as: R

  test "the normal progression of events" do

    # One of the Deeply operations checks if tracing is already in progress
    assert State.tracing_already_in_progress? == false

    # If not, it initializes the log
    State.start_log
    assert State.tracing_already_in_progress? == true
    assert State.get_log == []

    # A first descent produces this:
    State.log_descent(:key, [:a], %{a: %{b: 1}})
    assert State.get_log == [%D{name: :key, args: [:a], direction: :>,
                                container: %{a: %{b: 1}}}]

    # A second pushed into the state (which is handled like a LIFO stack)
    State.log_descent(:key, [:b], %{b: 1})
    assert State.get_log == [
             %D{name: :key, args: [:b], direction: :>, container:      %{b: 1}},
             %D{name: :key, args: [:a], direction: :>, container: %{a: %{b: 1}}}
           ]

    # A retreat also produces a log item:
    State.log_retreat(:key, [:b], [1], %{b: "1"})
    assert State.get_log == [
             %R{name: :key, args: [:b], direction: :<, gotten: [1], updated: %{b: "1"}},
             %D{name: :key, args: [:b], direction: :>, container:      %{b: 1}},
             %D{name: :key, args: [:a], direction: :>, container: %{a: %{b: 1}}}
           ]

    # You can peek at the log, which returns a reversed version:
    assert State.peek_at_log == [
             %D{name: :key, args: [:a], direction: :>, container: %{a: %{b: 1}}},
             %D{name: :key, args: [:b], direction: :>, container:      %{b: 1}},
             %R{name: :key, args: [:b], direction: :<, gotten: [1], updated: %{b: "1"}},
           ]

    # Now, it may be that a lens uses one of the Depth
    # functions. That's OK, because they'll discover that tracing is already in
    # progress and do nothing. (See the Tracing.wrap macro.)

    # Here, the final retreat:
    State.log_retreat(:key, [:a], [[1]], %{a: %{b: "1"}})

    # The `Deeply` function (which knows it was the outermost one) now finishes up.
    # It must first replace the final retreat value with the value it itself received.
    # (Lenses use continuation-passing style to simplify "gotten" values in a
    # flatmap kind of way. That's not captured at the exit from the lens, so it has to be
    # patched in

    assert %{gotten: [[1]]} = State.peek_at_log |> List.last

    State.patch_final_gotten(:PATCH)

    assert State.peek_at_log == [
             %D{name: :key, args: [:a], direction: :>, container: %{a: %{b: 1}}},
             %D{name: :key, args: [:b], direction: :>, container:      %{b: 1}},
             %R{name: :key, args: [:b], direction: :<, gotten: [1], updated: %{b: "1"}},
             %R{name: :key, args: [:a], direction: :<, gotten: :PATCH, updated: %{a: %{b: "1"}}}
           ]

    State.reset
    refute State.tracing_already_in_progress?
  end

  # The Deeply operation can't actually know if there are any `tracing_*` lenses in
  # its argument, so it needs to check:
  test "is_any_log?" do
    State.start_log
    refute State.has_accumulated_a_log?
    State.log_descent(:key, [:b], %{b: 1})
    assert State.has_accumulated_a_log?
  end


end
