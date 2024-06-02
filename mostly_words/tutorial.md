# Tutorial

This tutorial will show you how to use existing lenses and simple ways
to compose lenses into new lenses. 

## Why lenses?

Here I'll try to convince you that lenses have some advantages over
Elixir's built-in `Access` behaviour and its associated `Kernel`
functions: `put_in/2`, `update_in/2`, `put_in/2` and so on.

---

Languages like Elixir don't let you change data structures; instead,
you create a new data structure that's different from the
original. That can be somewhat annoying when you want to change a
single _place_ within a deeply nested structure. From now on, I'm
going to call such structures *containers*. We're interested in nested
containers.

Here's a simple example. We have `Network` structure. It has various
fields, one of which is named `:name_to_cluster`. A `Cluster`
structure has various fields, one of which, `:downstream`, holds a
`MapSet` of atoms (cluster names). We want to add the value `:c` to
all the MapSets.

There are a variety of ways that could be done. Here's an
implementation that uses `for`, taking advantage of the fact that maps
can be decomposed into `{key, value}` tuples:

```elixir
    addition = :c
    for {name, cluster} <- network.name_to_cluster, into: %{} do
        {name, Map.update!(cluster, :downstream, & MapSet.put(&1, addition))}
      end
    |> then(& Map.put(network, :name_to_cluster, &1))
```

**Am I losing it? Can this not actually be done with `Access`?**

I thought `Access.all` would work on a `Map`, producing a list of `{key, value}` tuples. But it fails. 


```
     ** (RuntimeError) Access.all/0 expected a list, got: %{gate: %Cluster{downstream: MapSet.new([:big_edit, :has_fragments]), name: :gate}, watcher: %Cluster{downstream: MapSet.new([]), name: :watcher}}
```