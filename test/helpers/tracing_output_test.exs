alias Lens2.Helpers.Tracing

defmodule Tracing.OutputTest do
  use Lens2.Case
  import ExUnit.CaptureIO

  def lines(f) when is_function(f, 0) do
    capture_io(f) |> lines
  end

  def lines(text) do
    text
    |> String.replace([IO.ANSI.green, IO.ANSI.yellow, IO.ANSI.reset], "")
    |> String.split("\n")
    |> Enum.reject(& &1 == "")
  end

  def op_specific_chunks(lines) do
    index_of = fn what ->
      Enum.find_index(lines, & Regex.match?(~r/\W+#{what}/, &1))
    end

    cut_bounded = fn start_after, finish_before ->
      Enum.slice(lines, start_after+1..finish_before-1)
    end

    cut_to_end = fn start_after ->
      Enum.slice(lines, start_after+1..-1//1)
    end

    case {index_of.("GET"), index_of.("UPDATE")} do
      {get_index, nil} ->
        [get: cut_to_end.(get_index)]
      {nil, update_index} ->
        [update: cut_to_end.(update_index)]
      {get_index, update_index} ->
        [get: cut_bounded.(get_index, update_index),
         update: cut_to_end.(update_index)]
    end
  end

  def assert_same_lines(actual_lines, expected_text) do
    expected_lines = lines(expected_text)
    pairs = Enum.zip(actual_lines, expected_lines)
    for {actual, expected} <- pairs do
      assert actual == expected
    end
    actual_count = length(actual_lines)
    expected_count = length(expected_lines)
    assert actual_count == expected_count,
           "Actual has #{actual_count} lines; expected has #{expected_count}"
  end

  def assert_update(map, lens, updater, expected_text) do
    f = fn -> Deeply.update(map, lens, updater) end
    [update: actual_lines] = lines(f) |> op_specific_chunks
    assert_same_lines(actual_lines, expected_text)
  end

  def assert_get_and_update(map, lens, descender, expected_get_text, expected_update_text) do
    f = fn -> Deeply.get_and_update(map, lens, descender) end
    [get: get_lines, update: update_lines] = lines(f) |> op_specific_chunks
    assert_same_lines(get_lines, expected_get_text)
    assert_same_lines(update_lines, expected_update_text)
  end


  def assert_get(map, lens, expected_text) do
    f = fn -> Deeply.get_all(map, lens) end
    [get: actual_lines] = lines(f) |> op_specific_chunks
    assert_same_lines(actual_lines, expected_text)
  end


  test "simple" do
    lens = Lens.tracing_key(:a)
    map =
      %{a: %{aa: %{aaa: 1}},
        b: %{aa: %{aaa: 2}}
      }

    assert_update(map, lens, &inspect/1,
      """
      >key(:a) || %{a: %{aa: %{aaa: 1}}, b: %{aa: %{aaa: 2}}}
      <key(:a) || %{a: "%{aa: %{aaa: 1}}", b: %{aa: %{aaa: 2}}}
      """)

    assert_get_and_update(map, lens, &{&1, inspect(&1)},
      """
      >key(:a) || %{a: %{aa: %{aaa: 1}}, b: %{aa: %{aaa: 2}}}
      <key(:a) || [%{aa: %{aaa: 1}}]
      """,
      """
      >key(:a) || %{a: %{aa: %{aaa: 1}}, b: %{aa: %{aaa: 2}}}
      <key(:a) || %{a: "%{aa: %{aaa: 1}}", b: %{aa: %{aaa: 2}}}
      """)

    assert_get(map, lens,
      """
      >key(:a) || %{a: %{aa: %{aaa: 1}}, b: %{aa: %{aaa: 2}}}
      <key(:a) || [%{aa: %{aaa: 1}}]
      """)
  end
end
