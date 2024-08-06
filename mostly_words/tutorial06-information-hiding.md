# Information hiding

This is unfinished. The points I mean to make are, at this moment, these:

1. If you have complicated data, there's a reasonable chance your
   first attempt at structuring it will be wrong. Or, at least, 
   adding new features will force restructuring.
   
   This is as true for
   functional languages (with their CRUD emphasis) as it is for OO
   languages.  (After all, the languages where ideas about
   [modularity and information hiding took](https://prl.khoury.northeastern.edu/img/p-tr-1971.pdf)
   root are at least arguably closer to modern functional languages
   than to modern OO languages.)

2. You want the inevitable restructuring to affect client code as
   little as possible. The fact that lenses are functions and
   functional programming loves it some function composition suggests
   that lenses make information hiding more idiomatic than `Access`
   (which requires concatenating lists). 
   
My own practice (which is still evolving) is to give each struct their own lenses. Here's an example. 

I use [`TypedStruct`](https://hex.pm/packages/typedstruct) to define
structs, because it's prettier and terser than `defstruct`. Here's an example.

     defmodule Cluster do
       typedstruct enforce: true do
         field :name, atom
         field :downstream, %{atom => MapSet.t(atom)}
       end

It seems reasonable to have a `downstream` lens:

    def_composed_maker downstream, do: Lens.key!(:downstream)

I find this preferable to having client code flaunt its knowledge of
`Cluster` structure with code like this:

    Deeply.get_only(cluster, Lens.key!(:downstream))
    
... or the equivalent:

    get_in(cluster, [Access.key(:downstream)])

Code like this:

    Deeply.get_only(cluster, Cluster.downstream)
    
... makes it less disruptive to change the `Cluster`
structure. Again: not a big deal with a shallowly nested container, but
lenses would be a waste of time if all structures were shallow and
predictable.

In fact, I like the CRUD abstraction enough that I've implemented shorthand
for cases where lens maker functions applied to structs take no arguments:

    Deeply.get_only(cluster, :downstream)
    
After all, `cluster` contains its type, so the function call can be constructed easily enough.

There's something appealing to me about client code that says "within
a cluster, there's a downstream. Fetch that, no matter where it is."

----

In this style, containers that contain smaller containers will use the
smaller containers' lens makers to make their own lens makers. So suppose
we have a `Network` that contains `Clusters`:

     defmodule Network do
       typedstruct enforce: true do
         field :clusters_by_name, %{atom => Cluster.t}
         field :other_fields, any, default: :just_for_show
       end

Clients of `Network` will want to extract a particular named cluster's
downstream, which can be done like this:


    def_composed_maker downstream_of(name),
      do: Lens.key!(:clusters_by_name) |> Lens.key!(name) |> Cluster.downstream
      
The important bit is that `Network` declines to make any guesses about
the structure of `Cluster`. It works from the lens API.

----

In the code I'm thinking of as I write, it turned out
that a `Cluster` will have not just one `downstream` list, but a
variety of them. You see, Clusters send "pulses" to their downstream
clusters. Originally, all pulses were the same, but later I needed to 
give pulses "types", so that there's a distinction between a
default pulse and a "control pulse". So suddenly, the `downstream` of
a cluster depends on the type of a pulse, so the code to retrieve the
downstream cluster names has to look like this:

    Deeply.get_all(network, Network.cluster_names(originating_cluster, pulse_type))
    
The important thing here is that, once we have the `cluster_names` function, client
code needn't care whether clusters contain a map of pulse types to
downstream names, meaning the path would be described like this:

    Lens.key!(:clusters_by_name)
    |> Lens.key!(originating_cluster)
    |> Lens.key(:downstream_by_pulse_type)
    |> Lens.key(pulse_type)

... or whether `Network` maintains a mapping from `{cluster, pulse_type`} to downstream names – removing from a `Cluster` any notion of its "downstream" clusters. That would mean this path:

     Lens.key!(:downstreams)
     |> Lens.key!({originating_cluster, pulse_type})
   

The point is: having lens makers be module functions makes change easier.