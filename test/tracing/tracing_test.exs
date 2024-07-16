alias Lens2.Tracing

defmodule Tracing.Test do
  use Lens2.Case
  alias Tracing.{State}
  require Tracing

  describe "wrapping a Deeply operation" do
    test "wrapper" do
      refute State.tracing_already_in_progress?
      result =
        Tracing.wrap [:get, :update] do
          assert State.tracing_already_in_progress?
          :result
        end
      assert result == :result
     refute State.tracing_already_in_progress?
    end

    test "Only outermost operation counts" do
      Tracing.wrap [:get] do
        assert State.tracing_already_in_progress?
        State.log_descent(:key, [:a], 1)
        assert [%{container: 1}] = State.peek_at_log
        Tracing.wrap [:different] do
          assert State.tracing_already_in_progress?
          State.log_descent(:key, [:zzz], 100)
          assert [%{container: 1}, %{container: 100}] = State.peek_at_log
        end
          assert [%{container: 1}, %{container: 100}] = State.peek_at_log
      end
      refute State.tracing_already_in_progress?
    end

    test "the Deeply operations announce themselves to tracing" do
      # This is wasted if the there are no tracing_ operations, but that's insignificant.
      actual =
        Deeply.update(%{a: 1}, Lens.key(:a), fn value ->
          assert State.tracing_already_in_progress?
          inspect value
        end)
      assert actual == %{a: "1"}

      # Non-update cases are tested implicitly.
    end
  end
end
