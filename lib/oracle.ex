defmodule Oracle do
  defstruct global: nil, default_junction: nil, default_segment: nil, current_junction: nil, current_segment: nil
  use GenServer

  def new(%Global{} = global) do
    {:ok, pid} = GenServer.start_link(__MODULE__, {global})
    pid
  end

  def edge_time(pid, from, to, time) do
    GenServer.call(pid, {:edge_time, from, to, time})
  end

#From may be nil if the route starts here
  def vertex_time(_pid, nil, _via, _to, _time) do
    0
  end

  def vertex_time(pid, from, via, _to, time) do
    GenServer.call(pid, {:vertex_time, from, via, time})
  end

  def calculate_default(pid) do
    :calculated = GenServer.call(pid, :calculate_default)
  end

  def default_delay_result(pid, type, from, to, estimation) do
    GenServer.call(pid, {:default, type, from, to, Dict.fetch!(estimation, 0)})
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
            |> Enum.each &spawn_default(&1, state.global, counter)
        end
    Counter.all_started(counter)
    {:noreply, state}
  end

  defp spawn_default({from, to, _}, global, counter) do
    pid = self()
#Create calls to junctions
    Counter.started(counter)
    junction_fn = &default_delay_result(pid, :junction, from, to, &1)
    Delay.spawn_junction(global, from, to, %{0 => 1}, junction_fn, counter)
#Create calls to segments
    Counter.started(counter)
    segment_fn = &default_delay_result(pid, :segment, from, to, &1)
    Delay.spawn_segment(global, from, to, %{0 => 1}, segment_fn, counter)
  end

  def handle_call({:default, :segment, from, to, time}, _from, state) do
    segments = Dict.put_new(state.default_segment, {from, to}, time)
    {:reply, :ok, %{ state | default_segment: segments} }
  end

  def handle_call({:default, :junction, from, via, time}, _from, state) do
    junctions = Dict.put_new(state.default_junction, {from, via}, time)
    {:reply, :ok, %{ state | default_junction: junctions} }
  end
end

