defmodule Lens2.MostlyText.ContinuationPassingTest do
  use Lens2.Case, async: true


  def map_put(map, key, value, continuation) do
    Map.put(map, key, value)
    |> continuation.()
  end



  test "simple" do
    assert map_put(%{}, :a, 1, & &1) == %{a: 1}
  end

  test "nested" do
    actual =
      map_put(%{}, :a, 1,
              fn map ->
                map_put(map, :b, 2,
                        & &1)
              end)
    assert actual == %{a: 1, b: 2}
  end


  test "hoist constants, part 1" do
    two_puts =
      fn initial_value, final_continuation ->
        map_put(initial_value, :a, 1,          # step 1
                fn map ->
                  map_put(map, :b, 2,          # step 2
                          final_continuation)
                end)
      end

    assert two_puts.(%{}, & &1) == %{a: 1, b: 2}
  end


  test "hoist constants, part 2, part 2" do
    step_combiner =
      fn step1, step2 ->
        fn initial_value, final_continuation ->
          step1.(initial_value,
                 fn map ->
                   step2.(map,
                          final_continuation)
                 end)
        end
      end

    two_puts =
      step_combiner.(
        fn map, continuation ->
          map_put(map, :a, 1, continuation)
        end,
        fn map, continuation ->
          map_put(map, :b, 2, continuation)
        end)

    assert two_puts.(%{}, & &1) == %{a: 1, b: 2}
  end


  def make_put_fn(key, value) do
    fn map, continuation ->
      Map.put(map, key, value) |> continuation.()
    end
  end

  def make_put_fn(previous, key, value) do
    step_combiner(previous, make_put_fn(key, value))
  end

  test "make_put_fn" do
    step_combiner =
      fn step1, step2 ->
        fn initial_value, final_continuation ->
          step1.(initial_value,
                 fn map ->
                   step2.(map,
                          final_continuation)
                 end)
        end
      end

    two_puts =
      step_combiner.(make_put_fn(:a, 1),
                     make_put_fn(:b, 2))

    assert two_puts.(%{}, & &1) == %{a: 1, b: 2}
  end


  def step_combiner(step1, step2) do
    fn initial_value, final_continuation ->
      step1.(initial_value,
             fn step2_value ->
               step2.(step2_value,
                      final_continuation)
             end)
    end
  end

  test "step_combiner" do
    step1 = make_put_fn(:a, 1)
    step2 = make_put_fn(:b, 2)

    put_twice = step_combiner(step1, step2)
    assert put_twice.(%{}, & &1) == %{a: 1, b: 2}
  end

  def do_to(structure, step) do
    step.(structure, & &1)
  end


  test "pipeline" do
    put_twice =
      make_put_fn(:a, 1)
      |> make_put_fn(:b, 2)

    assert do_to(%{c: 3}, put_twice) == %{a: 1, b: 2, c: 3}
  end




end
