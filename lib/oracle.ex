defmodule Oracle do
  defstruct global: nil, default_junction: nil, default_segment: nil, current_junction: nil, current_segment: nil
  use GenServer

  def new(%Global{} = global) do
    {:ok, pid} = GenServer.start_link(__MODULE__, {global})
    pid
  end

  def edge_time(pid, from, to, time) do
    GenServer.call(pid, {:edge_time, from, to, time}, :infinity)
  end

#From may be nil if the route starts here
  def vertex_time(_pid, nil, _via, _time) do
    0
  end

  def vertex_time(pid, from, via, time) do
    GenServer.call(pid, {:vertex_time, from, via, time}, :infinity)
  end

  def calculate_default(pid) do
    :calculated = GenServer.call(pid, :calculate_default, :infinity)
  end

  def default_delay_result(pid, type, from, to, estimation) do
    GenServer.cast(pid, {:default, type, from, to, Dict.fetch!(estimation, 0)})
  end

  def reset_current(pid) do
    GenServer.call(pid, :reset_current, :infinity)
  end

  def current_delay_result(pid, type, from, to, dict) do
    GenServer.cast(pid, {:current, type, from, to, dict})
  end

#GenServer
  def init({global}) do
    {:ok, %Oracle{global: global, default_junction: HashDict.new, default_segment: HashDict.new, current_junction: HashDict.new, current_segment: HashDict.new} }
  end

  def handle_call({:edge_time, from, to, time}, _from, state) do
    timeframe_fn = Global.timeframe_fn(state.global)
    tf = timeframe_fn.(time)
    default = fn -> Dict.fetch!(state.default_segment, {from, to}) end
    current = Dict.get(state.current_segment, {from, to})
    ret = if current == nil do
      default.()
    else
      duration = Dict.get(current, tf)
      if duration == nil do
        default.()
      else
        duration
      end
    end
    {:reply, ret, state}
  end

  def handle_call({:vertex_time, from, via, time}, _from, state) do
    timeframe_fn = Global.timeframe_fn(state.global)
    tf = timeframe_fn.(time)
    default = fn -> Dict.fetch!(state.default_junction, {from, via}) end
    current = Dict.get(state.current_junction, {from, via})
    ret = if current == nil do
      default.()
    else
      duration = Dict.get(current, tf)
      if duration == nil do
        default.()
      else
        duration
      end
    end
    {:reply, ret, state}
  end

  def handle_call(:calculate_default, from, state) do
    counter = Counter.new(fn (_) -> GenServer.reply(from, :calculated) end)
    #Get all vertices
    RoadMap.vertices(state.global.map)
      |> Enum.each fn(v) ->
          RoadMap.edges(state.global.map, v)
            |> Aggregator.chunk(100, &spawn_default(&1, state.global, counter))
        end
    Counter.all_started(counter)
    {:noreply, state}
  end

  def handle_call(:reset_current, _from, state) do
    {:reply, :ok, %Oracle{ state | current_segment: HashDict.new(), current_junction: HashDict.new()}}
  end

  def handle_cast({:default, :segment, from, to, time}, state) do
    segments = Dict.put_new(state.default_segment, {from, to}, time)
    {:noreply, %Oracle{ state | default_segment: segments} }
  end

  def handle_cast({:default, :junction, from, via, time}, state) do
    junctions = Dict.put_new(state.default_junction, {from, via}, time)
    {:noreply, %Oracle{ state | default_junction: junctions} }
  end

  def handle_cast({:current, :segment, from, to, dict}, state) do
    segments = Dict.put_new(state.current_segment, {from, to}, dict)
    {:noreply, %Oracle{ state | current_segment: segments} }
  end

  def handle_cast({:current, :junction, from, via, dict}, state) do
    junctions = Dict.put_new(state.current_junction, {from, via}, dict)
    {:noreply, %Oracle{ state | current_junction: junctions} }
  end  

  defp spawn_default(chunk, global, counter) do
    pid = self()
#Create calls to junctions
    Counter.spawn counter, fn -> 
        for {from, to, _l, _t} <- chunk do
          res = Delay.junction(global, from, to, %{0 => 1})
          default_delay_result(pid, :junction, from, to, res)
        end
      end
#Create calls to segments
    Counter.spawn counter, fn -> 
        for {from, to, _l, _t} <- chunk do
          res = Delay.segment(global, from, to, %{0 => 1})
          default_delay_result(pid, :segment, from, to, res)
        end
      end
  end
end

