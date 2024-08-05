# Missing and nil values

In Elixir, a `nil` sometimes means "there is nothing here" and
sometimes "there is something here, specifically `nil`.

    iex> Map.get(%{a: nil}, :a)
    nil
    iex> Map.get(%{      }, :a)
    nil

Sometimes you want to handle the two cases differently. For example:

    iex> Map.put_new(%{a: 1}, :a, :NEW)
    %{a: 1}
    iex> Map.put_new(%{    }, :a, :NEW)
    %{a: :NEW}

This page is how you navigate such distinctions when using lenses. Unlike
`Map`, where you choose an operation (`Map.put/3`
vs. `Map.put_new/3`), with lenses you choose a different lens maker.

## Keyed lenses (maps, structs, and `Access.fetch`)

Lenses for map structures come in three varieties, such as `Lens.key`,
`Lens.key?`, and `Lens.key!`. (There are also `Lens.keys`, `Lens.keys?`, and `Lens.keys!`.)

`Lens.key` treats a missing value and nil the same way:

    iex> use Lens2
    iex> Deeply.get_all(%{a: nil}, Lens.key(:a))
    [nil]
    iex> Deeply.get_all(%{      }, Lens.key(:a))
    [nil]

    iex> Deeply.put(%{a: nil}, Lens.key(:a), :NEW)
    %{a: :NEW}
    iex> Deeply.put(%{      }, Lens.key(:a), :NEW)
    %{a: :NEW}
    
    iex> Deeply.update(%{a: nil}, Lens.key(:a), &inspect/1)
    %{a: "nil"}
    iex> Deeply.update(%{      }, Lens.key(:a), &inspect/1)
    %{a: "nil"}
    
If the container is a struct, `Deeply.get_all` behaves the same as for
a plain map. It will still produce a `nil` for a missing key.

    iex> Deeply.get_all(%Point{}, Lens.key(:missing))
    [nil]
    
`Deeply.put` with a missing key is alarming:

    iex> Deeply.put(%Point{}, Lens.key(:missing), :NEW)
    %{missing: :NEW, y: 2, __struct__: Point, x: 1}
    
We've destroyed the contract for `Point`. This is, however, the same thing that `put_in/3` would do:

    iex> put_in(%Point{x: 1, y: 2}, [Access.key(:missing)], :NEW)
    %{missing: :NEW, y: 2, __struct__: Point, x: 1}
    
I assume there's a reason for that, but I don't know what it is.

`Deeply.update` can also be used to add fields to a struct, as can `update_in/3`.

    
### key?

`Lens.key?` or `Lens.keys?`, in contrast, treat `nil` as a regular value, but handle
a missing value by doing nothing. For `Deeply.get_all`, nothing is
included in the return list:

    iex> Deeply.get_all(%{a: nil, b: 1}, Lens.keys?([:a, :b, :missing]))
    [nil, 1] # `keys` would have provided an extra `nil`
    
`Deeply.put` will only override an existing value. (It's like a `put_not_new`.)

    iex> Deeply.put(%{a: nil, b: 1}, Lens.keys?([:a, :b, :missing]), :NEW)
    %{a: :NEW, b: :NEW}
    
For `Deeply.update`, the update function is never called for a missing value.

    iex> Deeply.update(%{a: nil, b: 1}, Lens.keys?([:a, :b, :missing]), &inspect/1)
    %{a: "nil", b: "1"}

`Lens.key?` works the same on structs as on plain maps: it cannot create missing values.

### key!
    
`Lens.key!` will raise an error whenever it detects any missing key.

    iex> Deeply.get_all(%{}, Lens.key!(:missing))
    ** (KeyError) key :missing not found in: %{}

    iex> Deeply.put(%{a: 1}, Lens.keys!([:a, :missing]), :NEW)
    ** (KeyError) key :missing not found in: %{a: :NEW}

    iex(30)> Deeply.put(%{}, Lens.key!(:missing), &inspect/1)
    ** (KeyError) key :missing not found in: %{}

Structs are handled the same way.

### Other types

Any container that implements the `Access` behaviour will be treated like a map.
More precisely, 

* `Lens.key` uses `Access.fetch/2` but converts an `:error` return
  value into `nil`. It uses `Access.get_and_update/3` to update (or
  put) values.
  
* `Lens.key?` uses the same two functions but does nothing in the case
  where `Access.fetch/2` returns `:error`.
  
* `Lens.key!` does the same, but it raises an error when
  `Access.fetch/2` returns `:error`.


## Indexed lenses (lists, tuples)

The core function is `Lens2.Lenses.Indexed.at/1`. It and its
derivative, `Lens2.Lenses.Indexed.indices/1`, will return `nil` when getting an
index that's out of bounds:

      iex> Deeply.get_all([0, 1], Lens.at(2))
      [nil]
      iex> Deeply.get_all([0, 1], Lens.indices([0, 10000]))
      [0, nil]
      
This is consistent with the behavior of `Enum.at/2` and also `Lens.key`.

When it comes to `Deeply.put` and `Deeply.update`, no change is made to an out-of-bound index:

    iex> Deeply.put([0, 1], Lens.at(2), :NEW)
    [0, 1]
    iex> Deeply.update([0, 1], Lens.indices([0, 2]), &inspect/1)
    ["0", 1]
    
This is consistent with `List.replace_at/3`. One annoyance when using
`Deeply.update` is that a `nil` (signifying "missing") is passed to the
update function and *then* the return value is ignored. That's a
problem in the common case when the update function doesn't expect a nil:

     iex> Deeply.update(["0", "1"], Lens.at(2), &Integer.parse/1)
     ** (FunctionClauseError) no function clause matching in Integer.parse/2
         The following arguments were given to Integer.parse/2:
        
             # 1
             nil
    

This is *not* consistent with the behavior of `update_in`, and I'm inclined to think it a bug. 

    iex> update_in(["0", "1"], [Access.at(2)], &Integer.parse/1)
    ["0", "1"]

### Tuples

`at` also works with tuples:

    iex> Deeply.get_all({"0", "1", "2"}, Lens.indices([0, 2]))
    ["0", "2"]
    iex> Deeply.update({0, 1, 2}, Lens.at(2), & &1 * 1111)
    {0, 1, 2222}

However, you cannot use an index out of range:

    iex> Deeply.get_all({"0", "1"}, Lens.at(2))
    ** (ArgumentError) errors were found at the given arguments:

            * 1st argument: out of range

This is consistent with `elem/2`.

You also get an `ArgumentError` when attempting to `put` or `update` a value out of range.

### Enumerable types

Although `Lens.at/1` is suggestive of `Enum.at/2`, you can't use it
with a non-list `Enumerable`. That makes sense for `put` and
`update`, since there's no general way to modify elements of an
`Enumerable`. Consider this:

    iex> Deeply.put(0..5, Lens.at(1), 2)
    ?????
    
What would that even mean?

It seems you should be able to use `Deeply.get_all`, but you can't
because of
[the lens implementation](implementation04-get_and_update.html).


### Lenses specifically for adding to lists

`Lens2.Lenses.Indexed` supplies lenses that point, not to elements of a list,
but *next to them*. Consider `Lens2.Lenses.Indexes.before/1`:

    iex> lens = Lens.before(2)
    
Given a list like `[0, 1, 2]`, it lets you add a new element:

    iex> Deeply.put(["0", "1", "2"], lens, :NEW)
    ["0", "1", :NEW, "2"]

It's rather peculiar to ask for a value at the place where there isn't
a value. If you do, you'll get a `nil`:

    iex> Deeply.get_all(["0", "1", "2"], Lens.before(2))
    [nil]
    
Similarly, you can use `Deeply.update`, but the update function will
always get a `nil`. Which is therefore a more elaborate version of
`Deeply.put`:

    iex> Deeply.update(["0", "1", "2"], Lens.before(2), fn nil -> :NEW end)
    [0, 1, :NEW, 2]

