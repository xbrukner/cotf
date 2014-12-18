defmodule Partitioner do
  defstruct pids: %{}, partition_fn: nil

  def new(module, init, partitions, partition_fn) do
    pids = for index <- 0..(partitions-1) do
      {:ok, pid} = GenServer.start_link(module, init)
      {index, pid}
    end
    pids = Enum.reduce(pids, %{}, fn ({k, v}, acc) -> Dict.put_new(acc, k, v) end)
    %Partitioner{ pids: pids, partition_fn: partition_fn }
  end

  def partition(%Partitioner{pids: pids, partition_fn: part}, type, params, prep_fn )
    when type == :cast do
    GenServer.cast( Dict.fetch!(pids, part.(params)), prep_fn.(params) )
  end

  def broadcast_ordered(%Partitioner{pids: pids}, type, params, prep_fn)
    when type == :call do
    for {_, pid} <- pids do
      GenServer.call( pid, prep_fn.(params), :infinity)
    end
  end

  def broadcast_ordered_aggregation(%Partitioner{pids: pids}, type, params, prep_fn, aggr_fn)
    when type == :call do
    for {_, pid} <- pids do
      GenServer.call( pid, prep_fn.(params), :infinity)
    end |> Enum.reduce aggr_fn
  end

  def per_pid_aggregation(%Partitioner{pids: pids}, type, params, prep_fn, aggr_fn)
    when type == :call do
    c = Dict.size(pids)
    ^c= Enum.count(params)
    Enum.zip(pids, params)
    |> Enum.map fn {{_, pid}, p} -> GenServer.call( pid, prep_fn.(p), :infinity ) end
    |> Enum.reduce aggr_fn
  end

  def first(%Partitioner{pids: pids}, type, params, prep_fn)
    when type == :call do
    GenServer.call( Dict.fetch!(pids, 0), prep_fn.(params), :infinity)
  end
end
