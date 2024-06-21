
defmodule Lens2.Lenses.CombineTest do
  use Lens2.Case, async: true

  doctest Lens2.Lenses.Combine


  test "both" do
    by_2 = Lens.filter(& rem(&1, 2) == 0)
    by_3 = Lens.filter(& rem(&1, 3) == 0)
    list = [0, 1, 2, 3, 4, 5, 6]
    lens = Lens.all |> Lens.both(by_2, by_3)
    assert Deeply.get_all(list, lens) == [0, 0, 2, 3, 4, 6, 6]

    actual = Deeply.update(list, lens, & &1 * 1111)
    assert actual == [0 * 1111 * 1111,
                      1, 2 * 1111, 3 * 1111, 4 * 1111, 5,
                      6 * 1111 * 1111]
  end

  describe "context" do
    test "getting returns both context/checkpoint and leaf" do
      map_0 = %{a: [0, :target_1, 2], b: 3}
      map_1 = %{a: [4, :target_5, 6], b: 7}
      map_list = [map_0, map_1]
      into_map = Lens.key(:a) |> Lens.at(1)
      lens = Lens.at(0) |> Lens.context(into_map)

      assert Deeply.get_only(map_list, lens) == {map_0, :target_1}

      lens = Lens.indices([0,1]) |> Lens.context(into_map)
      assert Deeply.get_all(map_list, lens) == [{map_0, :target_1},
                                                {map_1, :target_5}]

    end

    test "putting changes only leaf" do
      map_0 = %{a: [0, :target_1, 2], b: 3}
      map_1 = %{a: [4, :target_5, 6], b: 7}
      map_list = [map_0, map_1]
      into_map = Lens.key(:a) |> Lens.at(1)
      lens_with_context = Lens.at(0) |> Lens.context(into_map)
      lens_without_context = Lens.at(0) |> Lens.seq(into_map)

      actual = Deeply.put(map_list, lens_with_context, :replacement)
      expected = [Map.put(map_0, :a, [0, :replacement, 2]),
                  map_1]
      assert actual == expected
      # Also the same as not using context at all.
      actual = Deeply.put(map_list, lens_without_context, :replacement)
      assert actual == expected

      # Same works for multiple leafs
      lens_with_context = Lens.indices([0, 1]) |> Lens.context(into_map)
      lens_without_context = Lens.indices([0, 1]) |> Lens.seq(into_map)

      actual = Deeply.put(map_list, lens_with_context, :replacement)
      expected = [Map.put(map_0, :a, [0, :replacement, 2]),
                  Map.put(map_1, :a, [4, :replacement, 6])]
      assert actual == expected
      # Also the same as not using context at all.
      actual = Deeply.put(map_list, lens_without_context, :replacement)
      assert actual == expected
    end

    test "update" do
      map_0 = %{a: [10, 100, 1000], b: :"..."}
      map_list = [map_0, :"..."]
      lens_with_context = Lens.at(0) |> Lens.key(:a) |> Lens.context(Lens.at(1))

      f = fn {checkpoint, leaf} ->
        Enum.sum(checkpoint) + leaf
      end
      actual = Deeply.update(map_list, lens_with_context, f)
      assert actual == [%{a: [10, 1210, 1000], b: :"..."}, :"..."]
    end

    test "multiple contexts" do
      map_0 = %{a: [0, :target_1, 2], b: 3}
      map_1 = %{a: [4, :target_5, 6], b: 7}
      map_list = [map_0, map_1]
      lens = Lens.indices([0,1]) |> Lens.context(Lens.key(:a) |> Lens.context(Lens.at(1)))

      # get

      [gotten_0, gotten_1] = Deeply.get_all(map_list, lens)
      assert gotten_0 == {map_0, {[0, :target_1, 2], :target_1}}
      assert gotten_1 == {map_1, {[4, :target_5, 6], :target_5}}

      # put

      [put_0, put_1] = Deeply.put(map_list, lens, :REPLACE)
      assert put_0 == %{map_0 | a: [0, :REPLACE, 2]}
      assert put_1 == %{map_1 | a: [4, :REPLACE, 6]}

      # update

      map_0 = %{a: [10, 100, 1000], b: 9990000}
      map_list = [map_0, :"..."]
      lens = Lens.at(0) |> Lens.context(Lens.key(:a) |> Lens.context(Lens.at(1)))

      f = fn {outer, {inner, leaf}} ->
        outer.b + Enum.sum(inner) + leaf
      end
      actual = Deeply.update(map_list, lens, f)
      assert actual == [%{a: [10, 9991210, 1000], b: 9990000}, :"..."]


      # Lens1 |> Lens.context(lens1, lens2)

      # Lens.seq(Lens.remember(lens1), lens2)
    end
  end

  describe "const" do
    test "at end / key" do
      map = %{a: %{aa: 1}}
      lens = Lens.key(:a) |> Lens.key(:aa) |> Lens.const(1000)

      assert [1000] == Deeply.get_all(map, lens)

      assert %{a: %{aa: 9000}} == Deeply.update(map, lens, & &1 * 9)

      assert Deeply.put(map, lens, :NEW) == %{a: %{aa: :NEW}}
    end

    test "at end / key?" do
      map = %{a: %{aa: 1}}
      lens = Lens.key?(:a) |> Lens.key?(:aa) |> Lens.const(1000)

      assert [1000] == Deeply.get_all(map, lens)

      assert %{a: %{aa: 9000}} == Deeply.update(map, lens, & &1 * 9)

      assert Deeply.put(map, lens, :NEW) == %{a: %{aa: :NEW}}
    end

    test "in middle" do
      map = %{a: %{aa: 1}}
      lens = Lens.key(:a) |> Lens.const(%{aa: 8888}) |> Lens.key(:aa)

      assert [8888] == Deeply.get_all(map, lens)

      assert %{a: %{aa: 2222}} == Deeply.update(map, lens, & &1 / 4)

      assert Deeply.put(map, lens, :NEW) == %{a: %{aa: :NEW}}
    end


    ### These tests are unfinished

    def default(lens, default), do: Lens.either(lens, Lens.const(default))

    test "default requires `key?`" do
      lens_key? = Lens.key?(:a) |> default(:DEFAULT)
      lens_KEY = Lens.key(:a) |> default(:DEFAULT)

      present = %{not_a: :not_a, a: 1}


      # For get, what's the point?
      assert Deeply.get_all(present, Lens.key?(:a)) == [1]
      assert Deeply.get_all(present, Lens.key( :a)) == [1]

      assert Deeply.get_all(present, lens_key?) == [1]
      assert get_in(present,        [lens_key?]) == [1]
      assert Deeply.get_all(present, lens_KEY) == [1]
      assert get_in(present,        [lens_KEY]) == [1]

      # Ditto PUT
      assert Deeply.put(present, Lens.key?(:a),  :NEW) == %{a: :NEW, not_a: :not_a}
      assert Deeply.put(present, Lens.key( :a),  :NEW) == %{a: :NEW, not_a: :not_a}

      assert Deeply.put(present, lens_key?,  :NEW) == %{a: :NEW, not_a: :not_a}
      assert put_in(present,    [lens_key?], :NEW) == %{a: :NEW, not_a: :not_a}
      assert Deeply.put(present, lens_KEY,   :NEW) == %{a: :NEW, not_a: :not_a}
      assert put_in(present,    [lens_KEY],  :NEW) == %{a: :NEW, not_a: :not_a}


      # Ditto UPDATE
      assert Deeply.update(present, Lens.key?(:a), &inspect/1) == %{a: "1", not_a: :not_a}
      assert Deeply.update(present, Lens.key( :a), &inspect/1) == %{a: "1", not_a: :not_a}

      assert Deeply.update(present, lens_key?,  &inspect/1) == %{a: "1", not_a: :not_a}
      assert update_in(present,    [lens_key?], &inspect/1) == %{a: "1", not_a: :not_a}
      assert Deeply.update(present, lens_KEY,   &inspect/1) == %{a: "1", not_a: :not_a}
      assert update_in(present,    [lens_KEY],  &inspect/1) == %{a: "1", not_a: :not_a}



      missing = %{not_a: :not_a      }


      # The nil default for key/1 overrides the default
      assert Deeply.get_all(missing, Lens.key?(:a)) == []
      assert Deeply.get_all(missing, lens_key?) ==     [:DEFAULT]
      assert get_in(missing,        [lens_key?]) ==    [:DEFAULT]

      assert Deeply.get_all(missing, Lens.key( :a)) == [nil]
      assert Deeply.get_all(missing, lens_KEY) ==      [nil]
      assert get_in(missing,        [lens_KEY]) ==     [nil]

      # ---

      # Putting with `key?` is bizarre.
      assert Deeply.put(missing, Lens.key?(:a),  :NEW) == %{         not_a: :not_a}
      assert Deeply.put(missing, lens_key?,      :NEW) == :NEW
      assert put_in(missing,    [lens_key?],     :NEW) == :NEW

      # ... and putting with `key` adds nothing
      assert Deeply.put(missing, Lens.key( :a),  :NEW) == %{a: :NEW, not_a: :not_a}
      assert Deeply.put(missing, lens_KEY,       :NEW) == %{a: :NEW, not_a: :not_a}
      assert put_in(missing,    [lens_KEY],      :NEW) == %{a: :NEW, not_a: :not_a}

      # ---

      assert Deeply.update(missing, Lens.key?(:a), &inspect/1) == %{          not_a: :not_a}
      assert Deeply.update(missing, lens_key?,     &inspect/1) == ":DEFAULT"
      assert update_in(missing,    [lens_key?],    &inspect/1) == ":DEFAULT"

      assert Deeply.update(missing, Lens.key( :a), &inspect/1) == %{a: "nil", not_a: :not_a}
      assert Deeply.update(missing, lens_KEY,      &inspect/1) == %{a: "nil", not_a: :not_a}
      assert update_in(missing,    [lens_KEY],     &inspect/1) == %{a: "nil", not_a: :not_a}
    end

    @tag :skip
    test "use as default in middle" do
    end

    @tag :skip
    test "use as default at end" do
    end

  end



end
