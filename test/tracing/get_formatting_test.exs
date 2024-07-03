alias Lens2.Tracing

defmodule Tracing.GetTest do
  use Lens2.Case
  alias Tracing.Get

  test "creating an entry value" do
    Get.Value.new(%{direction: :>, container: %{m: 2, z: 3, a: 1}})
    |> assert_fields(direction: :>, output: "%{a: 1, m: 2, z: 3}")
  end

  test "creating an exit value" do
    Get.Value.new(%{direction: :<, gotten: [50, 60, 80, 81]})
    |> assert_fields(direction: :<, output: "[50, 60, 80, 81]")
  end

end
