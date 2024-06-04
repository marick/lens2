# Tutorial, part 1: are lens worth it to you?

Here I'll try to convince you that lenses have some advantages over
both recursive functions and Elixir's built-in `Access` behaviour and its
associated `Kernel` functions: `put_in/2`, `update_in/2`, `put_in/2`
and so on.

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
`MapSet` of atoms (cluster names). Like this:

<<<<PICK>>>>>

We want to add the value `:c` to
a single mapset. This code works:


```elixir
    new_cluster =
      network.name_to_cluster[:gate]
      |> Map.update!(:downstream, & MapSet.put(&1, :some_name))

    new_map =
      network.name_to_cluster
      |> Map.put(:gate, new_cluster)

    %{network | name_to_cluster: new_map}
```

Fine, but what I'm doing has two conceptual steps:

1. Point at the place you want to change.
2. Cause the change.

In the above code, those two steps are buried inside a lot of
bookkeeping code that does the work of constructing each level of the
new nested container. What really matters are highlighted below: the
path and the `MapSet.put` use.


We want the compiler to write the bookkeeping code for us, inserting
the path and update function.

You probably know that Elixir offers the `Access` behaviour that does
just that. Here's a better implementation of the above:

```elixir
    update_in(network.name_to_cluster[:gate].downstream,
              & MapSet.put(&1, :some_name))
```

Looks pretty clear: every word is about either the path or the
operation to be done on what's at the end. Alternately, we can use
syntax that's a little longer but not as reliant on macro magic to
describe the path:

```elixir
    path = [Access.key(:name_to_cluster), :gate, Access.key(:downstream)]
    update_in(network, path,
              & MapSet.put(&1, :some_name))
```

So where do lenses come in?

Well, let's say we want to add `:some_name` to *all* the clusters. I
was surprised that you couldn't do that with a single `update_in`
because I thought `Access.all/0` would do it. Something like:

```elixir
    path = [Access.key(:name_to_cluster),
            Access.all(),    # `all` will produce list of {key, value} tuples.
            Access.elem(1)]  # Take the value
```

But no joy:

```
** (RuntimeError) Access.all/0 expected a list, got: %{gate: %Cluster{downstream: MapSet.new([:big_edit, :has_fragments]), name: :gate}, watcher: %Cluster{downstream: MapSet.new([]), name: :watcher}}
```

(I don't know why `Access.all` is restricted to lists.)

To handle multiple clusters, you need some kind of a loop, perhaps
using `for`. `for` does what I expected `Access.all` to do, and
produces tuples:


```elixir
    new_map =
      for {name, cluster} <- network.name_to_cluster, into: %{} do
        new_cluster = update_in(cluster.downstream, & MapSet.put(&1, :some_name))
        {name, new_cluster}
      end
    %{network | name_to_cluster: new_map}
```

There are a variety of other looping or recursive styles you could use. (Actually,
that's sort of a problem: it would be better to have one concise
solution than, say, four that are long enough you actually have to
think to write them or, sometimes, read them.)


In this `Lens2` package (and others like it), updating multiple
clusters in the network doesn't require a loop:

```elixir
   lens = Lens.key(:name_to_cluster) |> Lens.map_values |> Lens.key(:downstream)
   #                                    ^^^^^^^^^^^^^^^
   Deeply.update(network, lens, & MapSet.update(&1, :some_name))
```

As it should, it looks almost the same to update a *subset* of the clusters:

```elixir
   lens = Lens.key(:name_to_cluster) |> Lens.keys([:gate, :watcher]) |> Lens.key(:downstream)
   #                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^
   Deeply.update(network, lens, & MapSet.update(&1, :some_name))
```

Or, if you prefer, you can use `update_in`, because lenses are
functions that implement the behavior that `Access` requires;


```elixir
    path = [Access.key(:name_to_cluster),  # Note Access
            Lens.keys([:gate, :watcher]),  # Note Lens
            Access.key(:downstream)]
    update_in(network, path, & MapSet.put(&1, :some_name))
```

This would be more compelling, I guess, if I were using maps instead
of structs. With maps, you can avoid `Access.key`:


```elixir
    path = [:name_to_cluster,
            Lens.keys([:gate, :watcher]),
            :downstream]
    update_in(network, path, & MapSet.put(&1, :some_name))
```

I personally just use `Deeply` everywhere except when the
`dot.and[bracket].notation` fits too well to pass up. I tend to avoid
nested structures that expose the structure of their innards to all
their clients, so that's not as often as you might guess.

You *can*, however, read this series as descriptions of how to create
custom path elements for `update_in` and friends (the way `Lens.keys`
was used above). You can do that directly by writing functions that
match the required `Access` behaviour, but since lenses *are*
functions that match that behaviour, and (I believe) are not (or not
much) harder to write than `Access` functions --- both are a *little*
brain-twisting --- maybe learning lenses is still worthwhile.

## Tradeoffs

Lenses, like `Access` are used for getting data from within nested
containers, for putting data in nested containers, and for updating
existing data. They're part of the long tradition of methods to do
CRUD (create/read/update/delete) that include relational databases,
HTTP verbs, and the like. Whether they're worth learning depends on
you and the work you do.

The out-of-the-box, batteries included, `Kernel` module functions
`get_in`, `put_in`, `update_in`, and `pop_in` let you solve some CRUD
problems without writing an annoying amount of bookkeeping code: they allow
short and declarative(ish) solutions. Others, they don't.

Sometimes lenses will work better, and let you write straightforward
solutions when `update_in` and friends would require more convoluted
ones. The question is whether *sometimes* is *often enough*. Not in
some abstract sense, but *for you* (and your team) and for what you do.

How often do you get annoyed writing boilerplate code around nested
data structures? (Or, probably equally important, how often do you not
create a nested structure because working with them is so annoying.)

And is that often enough that spending time seeing if learning lenses
(and using yet another package) is worth it?

(Sometimes `Access` can do things lenses won't, but I don't
think there are that many such cases. I'll point them out as this
series goes along.)

At this point, I've only shown you one example of how lenses are more
pleasant. I could list some other reasons why I've found lenses
worthwhile --- as you might guess, the `Cluster` example is derived
from my own code --- but, at this point, I think you're either
intrigued enough that you'll hold your reasonable skepticism in check
while you read on, or you aren't. If the former, continue! (You can
always give up later!)

#### A biographical note

It may seem weird and offputting to say you should decide on
lenses based on your personal and team annoyance with traversing nested
structures in a functional language. Surely I should be saying lenses
are better in some absolute sense? Well...

I got my first job as a programmer in 1975 (at the age of 16). I've
seen a *lot* of programmers making judgments about technology new to
them. When they reach for generalizations about "all programmers" or
"all programs", they tend to do poorly. For example, from about 1983
(when I was a Common Lisp implementor) to the early '90s, I heard an
endless number of people say that garbage collection was impractical
for "serious work". Machines (except for
[expensive custom hardware](https://en.wikipedia.org/wiki/Lisp_machine))
objectively just weren't fast enough, and would never *be* fast
enough. Then Java came out, and the conventional wisdom completely
dropped the issue, even for the slow machines of the day. Garbage
collection was now *assumed*: the question was how to use it most
efficiently, except that most programmers never thought about that at
all. They adopted the new "paradigm" and moved on.)

And don't get me started about the debate (around 1981) of whether C
could ever replace assembly language for serious coding.

In any case: I've seen too often programmer decisions about technology
that are based on personal preference, typically informed by what that
programmer is used to, but -- and let me emphasize this -- **presented
as something objective**. To that, I repeat the last line of Ernest
Hemingway's
[*The Sun Also Rises*](https://en.wikipedia.org/wiki/The_Sun_Also_Rises):
"wouldn't it be pretty to think so?"

I *don't* think so, so I won't pitch lenses to you as if you were a
dispassionate person optimizing some objective criterion. So:

1. If you are the exception, someone who really does weigh things objectively ---
   and I believe you might exist, you're just exceptional: welcome!
   The series will, I hope, give you enough information to rationally
   judge. But I'm not going to structure my argument around your
   criteria. Sorry!

2. If you accept that you are prone to subjective judgments: welcome!
   I hope to show you why my subjective judgment about lenses just
   might mesh with yours, and that you might find lenses pleasant.