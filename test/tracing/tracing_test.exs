alias Lens2.Tracing

defmodule Tracing.Test do
  use Lens2.Case
  alias Tracing.{State}
  require Tracing

  describe "wrapping a lens operation" do
    test "wrapper" do
      result =
        Tracing.wrap [:get, :update] do
          assert State.get_operations == [:get, :update]
          :result
        end
      assert result == :result
      assert State.get_operations == nil
    end

    test "Only outermost operation counts" do
      Tracing.wrap [:get, :update] do
        assert State.get_operations == [:get, :update]
        Tracing.wrap [:different] do
          assert State.get_operations == [:get, :update]
        end
        assert State.get_operations == [:get, :update]
      end
      assert State.get_operations == nil
    end

    test "the Deeply operations announce themselves to tracing" do
      # This is wasted if the there are no tracing_ operations, but that's insignificant.
      actual =
        Deeply.update(%{a: 1}, Lens.key(:a), fn value ->
          assert State.get_operations == [:update]
          inspect value
        end)
      assert actual == %{a: "1"}

      # Non-update cases are tested implicitly.
    end
  end
end
