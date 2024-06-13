defmodule Lens2.Lenses.CombineTest do
  use Lens2.Case, async: true

  doctest Lens2.Lenses.Combine

  describe "const" do
    test "at end / key" do
      map = %{a: %{aa: 1}}
      lens = Lens.key(:a) |> Lens.key(:aa) |> Lens.const(1000)

      assert [1000] == Deeply.to_list(map, lens)

      assert %{a: %{aa: 9000}} == Deeply.update(map, lens, & &1 * 9)

      assert Deeply.put(map, lens, :NEW) == %{a: %{aa: :NEW}}
    end

    test "at end / key?" do
      map = %{a: %{aa: 1}}
      lens = Lens.key?(:a) |> Lens.key?(:aa) |> Lens.const(1000)

      assert [1000] == Deeply.to_list(map, lens)

      assert %{a: %{aa: 9000}} == Deeply.update(map, lens, & &1 * 9)

      assert Deeply.put(map, lens, :NEW) == %{a: %{aa: :NEW}}
    end

    test "in middle" do
      map = %{a: %{aa: 1}}
      lens = Lens.key(:a) |> Lens.const(%{aa: 8888}) |> Lens.key(:aa)

      assert [8888] == Deeply.to_list(map, lens)

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
      assert Deeply.to_list(present, Lens.key?(:a)) == [1]
      assert Deeply.to_list(present, Lens.key( :a)) == [1]

      assert Deeply.to_list(present, lens_key?) == [1]
      assert get_in(present,        [lens_key?]) == [1]
      assert Deeply.to_list(present, lens_KEY) == [1]
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
      assert Deeply.to_list(missing, Lens.key?(:a)) == []
      assert Deeply.to_list(missing, lens_key?) ==     [:DEFAULT]
      assert get_in(missing,        [lens_key?]) ==    [:DEFAULT]

      assert Deeply.to_list(missing, Lens.key( :a)) == [nil]
      assert Deeply.to_list(missing, lens_KEY) ==      [nil]
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
