# DRAFT: Why `Lens.into` invites bugs

Here I'll describe a very common mistake using
`Lens2.Lenses.Enum.into/2`. This is sort of a digression, but it
reinforces some ideas from the previous two pages.

`Lens2.Lenses.Enum.all/0` turns a pointer to an `Enumerable` into a set of
pointers to all its elements. It's most often used with lists, but it
doesn't have to be.

     iex> use Lens2
     iex> Deeply.get_all(1..5, Lens.all)
     [1, 2, 3, 4, 5]

Suppose we want to increment each of the numbers. That doesn't
actually make sense for a range, but let's see what happens:

    iex> Deeply.update(1..5, Lens.all, & &1+1)
    [2, 3, 4, 5, 6]

Or just overwrite all the values:

    iex> Deeply.put(1..5, Lens.all, 1111)
    [1111, 1111, 1111, 1111, 1111]


For any update operation, `Lens.all/0` produces a list. Suppose we
instead want a `MapSet`. We could do that with `Enum.into/2`:

    iex> Deeply.put(1..5, Lens.all, 1111) |> Enum.into(MapSet.new)
    MapSet.new([1111])

(Notice that collapsed all the `11111` values into one, because
MapSets don't allow duplicates. Maybe that's why we wanted a `MapSet`.)

There is, however, a lens that is the equivalent of `Enum.into/2`:
`Lens2.Lenses.Enum.into/2`:

    iex> Deeply.put(1..5, Lens.all |> Lens.into(MapSet.new), 11111)
    MapSet.new([11111])

Looks good. Let's even put it in a module a a predefined lens maker:

    defmodule MyLenses do
      defmaker as_mapset,
        do: Lens.all |> Lens.into(MapSet.new)
    end

Now it happens that we have a structure containing a range, and we
want to increment the range values into a mapset. Seems easy:


    iex> lens = Lens.key(:a) |> MyLenses.as_mapset
    iex> Deeply.update(%{a: 1..5}, lens, & &1+1)
    %{a: MapSet.new([2, 3, 4, 5, 6])}
    
That looks good. Time passes, and you come across a similar situation. This time you decide a named lens maker is overkill. You'll just pipe the lenses together at the point of use:

    iex> lens = Lens.key(:a) |> Lens.all |> Lens.into(MapSet.new)
    iex> Deeply.update(%{a: 1..5}, lens, & &1+1)
    MapSet.new([a: [2, 3, 4, 5, 6]])
    
Look closely at that: it's not a map containing a mapset. It's a
mapset containing a keyword list.

Two questions: 

1. What went wrong with this?

        Lens.key(:a) |> Lens.all |> Lens.into(MapSet.new)

2. And why did *this* work...?

        lens = Lens.key(:a) |> MyLenses.as_mapset
    
   ...given that `as_mapset` is just:

        Lens.all |> Lens.into(MapSet.new)
 
## Why the pipeline fails

What if we manually expand out the pipeline into a nested pair of `Lens.seq`?

    Lens.seq(Lens.key(:a), Lens.seq(Lens.all, Lens.into(MapSet.new)))
    ** (UndefinedFunctionError) function Lens2.Lenses.into/1 is undefined or private. Did you mean:

      * into/2
      * into/3

`Lens.all |>`



## Why the named function doesn't fail