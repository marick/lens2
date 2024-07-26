defmodule Mix.Tasks.Timings.Keyed do
  @moduledoc """
  Crude timings that compare Access and Lens operations on a struct+map container.

  The container has this structure:

       .Network{
         cluster_count: 10,
         names_by_index: %{
           1 => :name1,
           2 => :name2,
           3 => :name3,
           ...
         },
         clusters_by_name: %{
           name1: %Mix.Tasks.Timings.Keyed.Cluster{
             router: %{c: 0, a: 0, d: 0, b: 0, e: 0},
             fun: &Kernel.inspect/1,
             string: ":name1",
             atom1: :name1
           },
           name2: %Mix.Tasks.Timings.Keyed.Cluster{
             router: %{c: 0, a: 0, d: 0, b: 0, e: 0},
             fun: &Kernel.inspect/1,
             string: ":name2",
             atom1: :name2
           },
           ...
         }
       }

  Get operations (get_in, Deeply.get_all) extract values like

       network.clusters_by_name[:name2].router.[:c]

  Update operations increment those values.

  Call with a list of the number of clusters:

        % mix timings.keyed 10 100 1000

  Each number creates a scaled network and runs the operation 40_000_000 times.

  I wrote this because I realized that `Deeply.get_all` will create a
  copy of the original structure as it "retreats" from finding the
  gotten values. Fortunately, for maps and structs,
  `Map.put(container, key, new_value)` actually returns the original
  `container` if the new value is the same as the existing value, so
  that's not so bad. But it's interesting to compare Access to Lens anyway.
  """

  use Mix.Task

  @impl Mix.Task
  def run([]) do
    time_with_node_count(10, 40_000_000)
  end

  def run(args) do
    node_counts =
      for a <- args, do: Integer.parse(a) |> elem(0)
    for count <- node_counts do
      time_with_node_count(count, 40_000_000)
      IO.puts("\n")
    end
  end



  use TypedStruct
  use Lens2
  import Lens2.Helpers.Section

  section "the data structures" do

    defmodule Router do
      typedstruct enforce: true do
        field :target_by_route, %{atom => integer}
      end

      def destinations, do: [:a, :b, :c, :d, :e]

      def new do
        for dest <- destinations(), into: %{}, do: {dest, 0}
      end
    end

    typedstruct module: Cluster, enforce: true do
      field :atom1, atom
      field :string, String.t
      field :fun, fun
      field :router, Router.t
    end

    typedstruct module: Network, enforce: true do
      field :clusters_by_name, %{atom => Cluster.t}, default: %{}
      field :names_by_index, %{integer => atom}, default: %{}
      field :cluster_count, integer
    end

    def create_network(cluster_count) do

      names_by_index =
        for i <- 1..cluster_count, into: %{} do
          {i, String.to_atom("name#{i}")}
        end

      clusters_by_name =
        for i <- 1..cluster_count, into: %{} do
          name = names_by_index[i]
          cluster = %Cluster{atom1: name, string: inspect(name), fun: &inspect/1,
                             router: Router.new}
          {name, cluster}
        end

      struct(Network, clusters_by_name: clusters_by_name,
                      names_by_index: names_by_index,
                      cluster_count: cluster_count)
    end
  end

  section "paths" do
    def_composed_maker lens_path(name, destination) do
      Lens.key!(:clusters_by_name)
      |> Lens.key!(name)
      |> Lens.key!(:router)
      |> Lens.key!(destination)
    end

    def access_path(name, destination) do
      [Access.key(:clusters_by_name),
       name,
       Access.key(:router),
       destination]
    end
  end

  section "operations" do
    def repeatedly_update(one_call, network, iterations) do
      Enum.reduce(1..iterations, network, fn _, acc ->
        {acc, _name} = call_on_random_cluster(one_call, acc)
        acc
      end)
    end

    def repeatedly_get(one_call, network, iterations) do
      Enum.reduce(1..iterations, %{}, fn _, acc ->
        {_, name} = call_on_random_cluster(one_call, network)
        Map.update(acc, name, 0, & &1+1)
      end)
    end

    def call_on_random_cluster(one_call, network) do
      index = :rand.uniform(network.cluster_count)
      name = network.names_by_index[index]
      destination = Enum.random(Router.destinations)
      {one_call.(network, name, destination), name}
    end

    def one_call(tuple) do
      case tuple do
        {:get, Access} ->
          fn network, name, destination ->
            get_in(network, access_path(name, destination))
          end
        {:get, Lens} ->
          fn network, name, destination ->
            Deeply.get_all(network, lens_path(name, destination))
          end
        {:update, Access} ->
          fn network, name, destination ->
            update_in(network, access_path(name, destination), & &1+1)
          end
        {:update, Lens} ->
          fn network, name, destination ->
            Deeply.update(network, lens_path(name, destination), & &1+1)
          end
      end
    end

    def repeater(:get), do: &repeatedly_get/3
    def repeater(:update), do: &repeatedly_update/3
  end

  def time(operation, algorithm, network, iterations) do
    one_call = one_call({operation, algorithm})

    {microseconds, retval} =
      :timer.tc(fn ->
        repeater(operation).(one_call, network, iterations)
      end)

    IO.puts "#{algorithm}, #{operation}: #{microseconds / 1_000_000} seconds"
    retval
  end

  def time_with_node_count(cluster_count, iteration_count) do
    network = create_network(cluster_count)

    IO.puts "Network with #{network.cluster_count} nodes, #{iteration_count} iterations"
    time(:update, Access, network, iteration_count)
    network = time(:update, Lens, network, iteration_count)
    # Might as well use the updated network for get operations

    time(:get, Access, network, iteration_count)
    time(:get, Lens, network, iteration_count)

  end
end
