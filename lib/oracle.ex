defmodule Oracle do
  defstruct default: nil, current: nil, global: nil
  #ETS format - default
  # {{:segment, from, to}, estimate}
  # {{:junction, from, via}, estimate}
  #ETS format - current
  # {{:segment, from, to, start}, estimate}
  # {{:junction, from, via, start}, estimate}

  def new(%Global{} = global) do
    default = :ets.new(:oracle_default, [
        :set, :public,
        {:write_concurrency, :true},
        {:read_concurrency, :true}
      ])
    current = :ets.new(:oracle_current, [
        :set, :public,
        {:write_concurrency, :true},
        {:read_concurrency, :true}
      ])
    %Oracle{ default: default, current: current, global: global }
  end

  def edge_time(%Oracle{} = oracle, from, to, time) do
    find_time(oracle, :segment, from, to, time)
  end

#From may be nil if the route starts here
  def vertex_time(_oracle, nil, _via, _time) do
    0
  end

  def vertex_time(%Oracle{} = oracle, from, via, time) do
    find_time(oracle, :junction, from, via, time)
  end

  def default_delay_result(%Oracle{default: default}, type, from, to, estimation)
    when type == :junction or type == :segment
  do
    :ets.insert(default, {{type, from, to}, Dict.fetch!(estimation, 0)})
  end

  def reset_current(%Oracle{current: current}) do
    :ets.delete_all_objects(current)
  end

  def current_delay_result(%Oracle{current: current}, type, from, to, dict)
    when type == :junction or type == :segment
  do
    data = Enum.map(dict, fn ({start_time, estimation}) ->
      {{type, from, to, start_time}, estimation}
    end)
    :ets.insert(current, data)
  end

  defp find_time(%Oracle{default: default, current: current, global: global}, type, from, to, time) do
    timeframe_fn = Global.timeframe_fn(global)
    tf = timeframe_fn.(time)
    default_match = {{type, from, to}, :_}
    current_match = {{type, from, to, tf}, :_}

    case :ets.match_object(current, current_match) do
      [{_, estimate}] -> estimate
      [] ->
        [{_, estimate}] = :ets.match_object(default, default_match)
        estimate
    end
  end

  def calculate_default(%Oracle{global: global} = oracle) do
    RoadMap.edges(global.map) #All vertices
    |> Stream.chunk(100, 100, []) #Cut into chunks of 100 edges
    |> Stream.map(&Task.async(fn -> calculate_defaults(oracle, &1) end)) #Start all as async tasks
    |> Enum.reduce(nil, fn (t, _) -> Task.await(t) end) #Wait for all tasks to finish
  end

  defp calculate_defaults(%Oracle{global: global} = oracle, chunk) do
    for {from, to, _l, _t} <- chunk do
      junction = Delay.junction(global, from, to, %{0 => 1})
      default_delay_result(oracle, :junction, from, to, junction)
      segment = Delay.segment(global, from, to, %{0 => 1})
      default_delay_result(oracle, :segment, from, to, segment)
    end
  end
end
