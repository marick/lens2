defmodule Lens2.MostlyText.ImplementationV4AccessTest do
  use ExUnit.Case, async: true

  defmodule DefMaker do
    defmacro def_maker(header = {name, _, args}, do: lens_code) do
      args = force_arglist(args)

      quote do
        def unquote(header) do
          lens = unquote(lens_code)

          fn
            :get, container, continuation ->
              {list, _} = lens.(container, &{&1, &1})
              continuation.(list)

            :get_and_update, container, tuple_returner ->
              lens.(container, tuple_returner)
          end
        end

        @doc false
        def unquote(name)(previous, unquote_splicing(args)) do
          Lens.seq(previous, unquote(name)(unquote_splicing(args)))
        end
      end
    end

    # A missing arglist is passed to a macro as `nil`, rather than `[]`.
    defp force_arglist(args) do
      case args do
        nil -> []
        _ -> args
      end
    end
  end

  defmodule Derply do
    def get_and_update(container, lens, tuple_returner) do
      Kernel.get_and_update_in(container, [lens], tuple_returner)
    end

    def update(container, lens, update_fn) do
      Kernel.update_in(container, [lens], update_fn)
    end

    def get_all(container, lens) do
      Kernel.get_in(container, [lens])
    end
  end


  defmodule V4 do
    import DefMaker

    def_maker at(index) do
      fn container, descender ->
        {gotten, updated} =
          Enum.at(container, index)
          |> descender.()

        {[gotten],
         List.replace_at(container, index, updated)
        }
      end
    end

    def_maker seq(outer_lens, inner_lens) do
      fn outer_container, inner_descender ->
        outer_descender =
          fn inner_container ->
            Derply.get_and_update(inner_container, inner_lens, inner_descender)
          end

        {gotten, updated} =
          Derply.get_and_update(outer_container, outer_lens, outer_descender)

        {Enum.concat(gotten), updated}
      end
    end

    # No change needed
    def_maker all do
      fn container, descender ->
        pairs =
          for item <- container, do: descender.(item)
        Enum.unzip(pairs)
      end
    end
  end



  test "at called alone" do
    lens = V4.at(1)
    container = [0, 1, 2]
    expected = { [1], [0, "1", 2] }
    tuple_returner = & {&1, inspect(&1)}

    assert Derply.get_and_update(container, lens, tuple_returner) == expected
    assert Derply.update(container, lens, &inspect/1) == elem(expected, 1)
    assert Derply.get_all(container, lens) == elem(expected, 0)
  end

  test "using seq" do
    lens = V4.seq(V4.at(0), V4.at(1))
    container = [[0, 1, 2], [], []]
    expected = { [1], [[0, "1", 2], [], []] }
    tuple_returner = & {&1, inspect(&1)}

    assert Derply.get_and_update(container, lens, tuple_returner) == expected
    assert Derply.update(container, lens, &inspect/1) == elem(expected, 1)
    assert Derply.get_all(container, lens) == elem(expected, 0)
  end

  test "longer" do
    container = [
                  [0],
                  [
                    [00],
                    [11],
                    [
                      :---,
                      :---,
                      :---,
                       333
                    ],
                  [33]
                 ],
                 [2],
                 [3]
               ]
    expected = [
                  [0],
                  [
                    [00],
                    [11],
                    [
                      :---,
                      :---,
                      :---,
                      3330033300333
                    ],
                  [33]
                 ],
                 [2],
                 [3]
               ]
    lens = V4.seq(V4.at(1), V4.seq(V4.at(2), V4.at(3)))

    assert Derply.get_and_update(container, lens, & {&1, &1 * 10000100001}) == {[333], expected}
    assert Derply.update(container, lens, & &1 * 10000100001) == expected
    assert Derply.get_all(container, lens) == [333]
  end

  test "all" do
    container = [ [0, 1, 2], [0, 1111, 2222], [:a, :b, :c] ]
    expected = [ [0, "1", 2], [0, "1111", 2222], [:a, ":b", :c]]
    lens = V4.seq(V4.all(), V4.at(1))
    tuple_returner = & {&1, inspect(&1)}

    assert Derply.get_and_update(container, lens, tuple_returner) == { [ 1, 1111, :b], expected}
    assert Derply.update(container, lens, &inspect/1) == expected
    assert Derply.get_all(container, lens) == [ 1, 1111, :b]
  end
end
