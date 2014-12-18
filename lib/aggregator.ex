defmodule Aggregator do
  defstruct global: nil, segments: nil, junctions: nil
  use GenServer

  def new(%Global{} = g) do
    {:ok, pid} = GenServer.start_link(__MODULE__, g)
    pid
  end

  def insert(pid, {from, via, to, segment_time, junction_time}) do
    GenServer.cast(pid, {:insert, from, via, to, segment_time, junction_time})
  end

  def delete(pid, {from, via, to, segment_time, junction_time}) do
    GenServer.cast(pid, {:delete, from, via, to, segment_time, junction_time})
  end

  def update(pid, old, new) do
    delete(pid, old)
    insert(pid, new)
  end

  def get_info(pid) do
    GenServer.call(pid, :info)
  end

  def calculate_delay(pid) do
     :calculated = GenServer.call(pid, :calculate)
  end

  def compare(pid, %Aggregator{} = previous) do
    GenServer.call(pid, {:compare, previous})
  end

  def write_results(map, prefix, %Aggregator{} = original, %Aggregator{} = latest) do
    extract_max_key = fn ({k, _}, acc) -> Kernel.max k, acc end
    extract_max_dict = fn ({_, dict}, acc) -> Kernel.max acc, Enum.reduce(dict, -1, extract_max_key) end
    extract_max_tf = &Enum.reduce(&1, -1, extract_max_dict)

    max_tf_junctions = Kernel.max extract_max_tf.(original.junctions), extract_max_tf.(latest.junctions)
    max_tf_segments = Kernel.max extract_max_tf.(original.segments), extract_max_tf.(latest.segments)
    max_tf = Kernel.max max_tf_junctions, max_tf_segments

#Segment:
#from, to, length, type, .... orig cars ...., ....latest cars....
#Junction:
#from, via, type, .... orig cars ...., ....latest cars....

    write_segment(map, prefix, max_tf, original.segments, latest.segments)
    write_junction(map, prefix, max_tf, original.junctions, latest.junctions)
    max_tf
  end
  
  defp write_segment(map, file_prefix, max_tf, original, latest) do
    {:ok, file} = File.open("#{file_prefix}segments.csv", [:write, :utf8])
    RoadMap.vertices(map)
      |> Enum.each fn(v) ->
          RoadMap.edges(map, v)
          |> Enum.each &write_single_segment(&1, file, max_tf, original, latest)
        end
    File.close(file) 
  end

  defp write_junction(map, file_prefix, max_tf, original, latest) do
    {:ok, file} = File.open("#{file_prefix}junctions.csv", [:write, :utf8])
    RoadMap.vertices(map)
      |> Enum.each fn(v) ->
          RoadMap.edges(map, v)
          |> Enum.each &write_single_junction(&1, map, file, max_tf, original, latest)
        end
    File.close(file) 
  end

  defp write_single_segment({from, to, length, type}, file, max_tf, original, latest) do
    IO.write file, "#{from},#{to},#{length},#{type},"
    write_cars file, max_tf, Dict.get(original, {from, to})
    IO.write file, ","
    write_cars file, max_tf, Dict.get(latest, {from, to})
    IO.write file, "\n"
  end

  defp write_single_junction({from, via, _length, _type}, map, file, max_tf, original, latest) do
    type = RoadMap.vertex_type(map, via)
    IO.write file, "#{from},#{via},#{type},"
    write_cars file, max_tf, Dict.get(original, {from, via})
    IO.write file, ","
    write_cars file, max_tf, Dict.get(latest, {from, via})
    IO.write file, "\n"
  end

  defp write_cars(file, max_tf, nil) do
    str = Stream.cycle([0])
    |> Enum.take(max_tf + 1)
    |> Enum.join(",")
    IO.write file, str
  end

  defp write_cars(file, max_tf, dict) do
    range = for i <- 0..max_tf do
      Dict.get(dict, i, 0)
    end
    IO.write file, Enum.join(range, ",")
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

  def handle_cast({:delete, from, via, to, segment_time, junction_time}, state) do
    timeframe_fn = Global.timeframe_fn(state.global)
    s_tf = timeframe_fn.(segment_time)
    j_tf = timeframe_fn.(junction_time)

    segments = HashDict.update!(state.segments, {from, via},
        fn (d) -> Dict.update!(d, s_tf, &(&1 - 1)) end)
    
    if to != nil do
      junctions = HashDict.update!(state.junctions, {from, via},
          fn (d) -> Dict.update!(d, j_tf, &(&1 - 1)) end)
    else
      junctions = state.junctions
    end
    {:noreply, %Aggregator{ global: state.global, segments: segments, junctions: junctions} }
  end

  def handle_call(:info, _from, state) do
    {:reply, state, state}
  end

  def handle_call(:calculate, from, state) do
    Oracle.reset_current(state.global.oracle)
    counter = Counter.new(fn (_) -> GenServer.reply(from, :calculated) end)
    #Get all segments
    Enum.each state.segments, &spawn_current_segment(&1, state.global, counter)

    #Get all junctions
    Enum.each state.junctions, &spawn_current_junction(&1, state.global, counter)

    Counter.all_started(counter)
    {:noreply, state}
  end

  def handle_call({:compare, %Aggregator{ segments: l_segments, junctions: l_junctions}}, _from, state) do
    {:reply, l_segments == state.segments and l_junctions == state.junctions, state}
  end

  defp spawn_current_junction({{from, to}, dict}, global, counter) do
    Counter.spawn counter, fn -> Delay.junction(global, from, to, dict) end,
        &Oracle.current_delay_result(global.oracle, :junction, from, to, &1)
  end

  defp spawn_current_segment({{from, to}, dict}, global, counter) do
    Counter.spawn counter, fn -> Delay.segment(global, from, to, dict) end,
        &Oracle.current_delay_result(global.oracle, :segment, from, to, &1) 
  end

end

