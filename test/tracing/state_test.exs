alias Lens2.Tracing

defmodule Tracing.StateTest do
  use Lens2.Case
  alias Tracing.State

  test "the normal progression of events" do

    # One of the Deeply operations checks if tracing is already in progress
    assert State.tracing_already_in_progress? == false

    # If not, it initializes the log
    State.start_log
    assert State.tracing_already_in_progress? == true
    assert State.get_log == []

    # A first descent produces this:
    State.log_descent(%{a: %{b: 1}})
    assert State.get_log == [%State.DescentItem{container: %{a: %{b: 1}}, direction: :>}]

    # A second pushed into the state (which is handled like a LIFO stack)
    State.log_descent(%{b: 1})
    assert State.get_log == [
             %State.DescentItem{container: %{b: 1}, direction: :>},
             %State.DescentItem{container: %{a: %{b: 1}}, direction: :>}
           ]

    # A retreat also produces a log item:
    State.log_retreat([1], %{b: "1"})
    assert State.get_log == [
             %State.RetreatItem{gotten: [1], updated: %{b: "1"}, direction: :<},
             %State.DescentItem{container: %{b: 1}, direction: :>},
             %State.DescentItem{container: %{a: %{b: 1}}, direction: :>}
           ]

    # For testing purposes, you can peek at the log, which reverses it:
    assert State.peek_at_log == [
             %State.DescentItem{container: %{a: %{b: 1}}, direction: :>},
             %State.DescentItem{container: %{b: 1}, direction: :>},
             %State.RetreatItem{gotten: [1], updated: %{b: "1"}, direction: :<},
           ]

    # Now, it may be that a lens uses one of the Depth
    # functions. That's OK, because they'll discover that tracing is already in
    # progress and do nothing. (See the Tracing.wrap macro.)

    # Here, the final retreat:
    State.log_retreat([[1]], %{a: %{b: "1"}})

    # The `Deeply` function (which knows it was the outermost one) now finishes up.
    # It must first replace the final retreat value with the value it itself received.
    # (Lenses use continuation-passing style to simplify "gotten" values in a
    # flatmap kind of way. That's not captured at the exit from the lens, so it has to be
    # patched in

    assert %{gotten: [[1]]} = State.peek_at_log |> List.last

    State.patch_final_gotten(:PATCH)

    assert State.destructive_read == [
             %State.DescentItem{container: %{a: %{b: 1}}, direction: :>},
             %State.DescentItem{container: %{b: 1}, direction: :>},
             %State.RetreatItem{gotten: [1], updated: %{b: "1"}, direction: :<},
             %State.RetreatItem{gotten: :PATCH, updated: %{a: %{b: "1"}}, direction: :<}
           ]

    refute State.tracing_already_in_progress?
  end


end
