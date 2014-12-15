defmodule Aggregator do
  defstruct global: nil, segments: nil, junctions: nil
  use GenServer

  def new(%Global{} = g) do
    {:ok, pid} = GenServer.start_link(__MODULE__, g)
    pid
  end

  def insert(pid, from, via, to, segment_time, junction_time) do
    GenServer.cast(pid, {:insert, from, via, to, segment_time, junction_time})
  end

  def get_info(pid) do
    GenServer.call(pid, :info)
  end

  def calculate_delay(pid) do
     :calculated = GenServer.call(pid, :calculate)
  end

#GenServer
  def init(g) do
    {:ok, %Aggregator{ global: g, segments: HashDict.new(), junctions: HashDict.new() } }
  end

  def handle_cast({:insert, from, via, to, segment_time, junction_time}, state) do
    timeframe_fn = Global.timeframe_fn(state.global)
    s_tf = timeframe_fn.(segment_time)
    j_tf = timeframe_fn.(junction_time)

    default_s = Dict.put_new(%{}, s_tf, 1)
    segments = HashDict.update(state.segments, {from, via}, 
              default_s, fn(d) -> Dict.update(d, s_tf, 1, &(&1 + 1)) end )

    if to != nil do
      default_j = Dict.put_new(%{}, j_tf, 1)
      junctions = HashDict.update(state.junctions, {from, via}, 
                default_j, fn(d) -> Dict.update(d, j_tf, 1, &(&1 + 1)) end )
    else
      junctions = state.junctions
    end
    {:noreply, %Aggregator{ global: state.global, segments: segments, junctions: junctions } }
  end

  def handle_call(:info, _from, state) do
    {:reply, state, state}
  end

  def handle_call(:calculate, from, state) do
    counter = Counter.new(fn (_) -> GenServer.reply(from, :calculated) end)
    #Get all segments
    Enum.each state.segments, &spawn_current(:segment, &1, state.global, counter)

    #Get all junctions
    Enum.each state.junctions, &spawn_current(:junction, &1, state.global, counter)

    Counter.all_started(counter)
    {:noreply, state}
  end

  defp spawn_current(type, {{from, to}, dict}, global, counter) do
    Counter.started(counter)
    finish_fn = &Oracle.current_delay_result(global.oracle, type, from, to, &1)
    if type == :junction do
      Delay.spawn_junction(global, from, to, dict, finish_fn, counter)
    else
      Delay.spawn_segment(global, from, to, dict, finish_fn, counter)
    end
  end
end

