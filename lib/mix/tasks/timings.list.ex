defmodule Mix.Tasks.Timings.List do
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
    time_with_node_count(10, 40_000)
  end

  def run(args) do
    node_counts =
      for a <- args, do: Integer.parse(a) |> elem(0)
    for count <- node_counts do
      time_with_node_count(count, 4_000_000)
      IO.puts("\n")
    end
  end



  use TypedStruct
  use Lens2
  import Lens2.Helpers.Section

  section "the data structures" do

    defmodule Router do
      @moduledoc false

      typedstruct enforce: true do
        field :target_by_route, %{atom => integer}
      end

      def destinations, do: [:a, :b, :c, :d, :e]

      def new do
        for dest <- destinations(), into: %{}, do: {dest, 0}
      end
    end

    defmodule Cluster do
      @moduledoc false
      # It is annoying that using `moduledoc false` with a typedstruct
      # causes warnings.
      defstruct [:int, :string, :fun, :router]
    end

    defmodule Network do
      @moduledoc false
      typedstruct enforce: true do
        field :clusters, [Cluster.t]
        field :cluster_count, integer
      end

      def new(cluster_count) do
        clusters =
          for i <- 0..cluster_count-1 do
            %Cluster{int: i, string: inspect(i), fun: &inspect/1,
                     router: Router.new}
          end

        struct(Network, clusters: clusters,
                        cluster_count: cluster_count)
      end
    end

  end

  section "paths" do
    @doc false
    defmaker lens_path(cluster_index, destination) do
      Lens.key!(:clusters)
      |> Lens.at(cluster_index)
      |> Lens.key!(:router)
      |> Lens.key!(destination)
    end

    defp access_path(cluster_index, destination) do
      [Access.key(:clusters),
       Access.at(cluster_index),
       Access.key(:router),
       destination]
    end
  end

  section "operations" do
    defp repeatedly_update(one_call, network, iterations) do
      Enum.reduce(1..iterations, network, fn _, acc ->
        {acc, _name} = call_on_random_cluster(one_call, acc)
        acc
      end)
    end

    defp repeatedly_get(one_call, network, iterations) do
      Enum.reduce(1..iterations, %{}, fn _, acc ->
        {_, index} = call_on_random_cluster(one_call, network)
        Map.update(acc, index, 0, & &1+1)
      end)
    end

    defp call_on_random_cluster(one_call, network) do
      index = :rand.uniform(network.cluster_count)-1
      destination = Enum.random(Router.destinations)
      {one_call.(network, index, destination), index}
    end

    defp one_call(tuple) do
      case tuple do
        {:get, Access} ->
          fn network, cluster_index, destination ->
            get_in(network, access_path(cluster_index, destination))
          end
        {:get, Lens} ->
          fn network, cluster_index, destination ->
            Deeply.get_all(network, lens_path(cluster_index, destination))
          end
        {:update, Access} ->
          fn network, cluster_index, destination ->
            update_in(network, access_path(cluster_index, destination), & &1+1)
          end
        {:update, Lens} ->
          fn network, cluster_index, destination ->
            Deeply.update(network, lens_path(cluster_index, destination), & &1+1)
          end
      end
    end

    defp repeater(:get), do: &repeatedly_get/3
    defp repeater(:update), do: &repeatedly_update/3
  end

  defp time(operation, algorithm, network, iterations) do
    one_call = one_call({operation, algorithm})

    {microseconds, retval} =
      :timer.tc(fn ->
        repeater(operation).(one_call, network, iterations)
      end)

    IO.puts "#{algorithm}, #{operation}: #{microseconds / 1_000_000} seconds"
    retval
  end

  defp time_with_node_count(cluster_count, iteration_count) do
    network = Network.new(cluster_count)

    IO.puts "Network with #{network.cluster_count} nodes, #{iteration_count} iterations"
    time(:update, Access, network, iteration_count)
    network = time(:update, Lens, network, iteration_count)
    # Might as well use the updated network for get operations

    time(:get, Access, network, iteration_count)
    time(:get, Lens, network, iteration_count)
  end
end
