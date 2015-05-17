defmodule Aggregator do
  #ETS format
  # segments: {{from, to, start}, estimate}
  # junctions: {{from, via, start}, estimate}
  defstruct global: nil, segments: nil, junctions: nil

  def new(%Global{} = g) do
    segments = :ets.new(:aggregator_segments, [
        :ordered_set, :public,
        {:read_concurrency, :true}
      ])
    junctions = :ets.new(:aggregator_junctions, [
        :ordered_set, :public,
        {:read_concurrency, :true}
      ])
    %Aggregator{global: g, segments: segments, junctions: junctions}
  end

  def insert(%Aggregator{segments: segments, junctions: junctions} = aggregator,
    {_from, _via, to, _st, _jt} = data) do

    {s_key, j_key} = get_keys(aggregator, data)

    if :ets.insert_new(segments, {s_key, 1}) == false do #Insert for non-existing key
      :ets.update_counter(segments, s_key, 1) #or update -> increment by one
    end
    if to != nil do #Also junction time
      if :ets.insert_new(junctions, {j_key, 1}) == false do
        :ets.update_counter(junctions, j_key, 1)
      end
    end
  end

  def delete(%Aggregator{segments: segments, junctions: junctions} = aggregator,
    {_from, _via, to, _st, _jt} = data) do

    {s_key, j_key} = get_keys(aggregator, data)
    :ets.update_counter(segments, s_key, -1) #Update -> no need for insertion, as key must have been there
    if to != nil do #Also junction time
      :ets.update_counter(junctions, j_key, -1)
    end
  end

  def update(aggregator, old, new) do
    delete(aggregator, old)
    insert(aggregator, new)
  end

  defp get_keys(%Aggregator{global: global}, {from, via, _to, segment_time, junction_time}) do
    timeframe_fn = Global.timeframe_fn(global)
    s_tf = timeframe_fn.(segment_time)
    s_key = {from, via, s_tf}
    j_tf = timeframe_fn.(junction_time)
    j_key = {from, via, j_tf} #Ignoring to = merging all together,

    {s_key, j_key}
  end

  #Tests only
  def get_info(%Aggregator{segments: segments, junctions: junctions}) do
    %{
      segments: :ets.tab2list(segments),
      junctions: :ets.tab2list(junctions)
    }
  end

  def get_copy(%Aggregator{segments: segments, junctions: junctions, global: global}) do
    n = new(global)
    copy_table(segments, n.segments)
    copy_table(junctions, n.junctions)
    n
  end

  defp copy_table(from, to) do
    get_resource(from, 50)
    |> Stream.each(&:ets.insert(to, &1))
    |> Stream.run
  end

  def stop(%Aggregator{segments: segments, junctions: junctions}) do
    :ets.delete(segments)
    :ets.delete(junctions)
  end

#Writing result to file
  def write_results(map, prefix, %Aggregator{} = original, %Aggregator{} = latest) do
    #Calculate maximum on all tables in parallel
    max_tf = [original.segments, original.junctions, latest.segments, latest.junctions]
    |> Enum.map(fn table -> Task.async(fn -> :ets.foldl(table, -1, &max_tf/2) end) end)
    |> Enum.map(&Task.await/1)
    |> Enum.max

#Segment:
#from, to, length, type, .... orig cars ...., ....latest cars....
#Junction:
#from, via, type, .... orig cars ...., ....latest cars....

    #Write to both files in parallel
    segments = Task.async(fn -> write_segment(map, prefix, max_tf, original, latest) end)
    junctions = Task.async(fn -> write_junction(map, prefix, max_tf, original, latest) end)

    Task.await(segments)
    Task.await(junctions)

    max_tf
  end

  defp max_tf({{_type, _from, _to, tf}, _count}, max) do
    Kernel.max(tf, max)
  end

  defp write_segment(map, file_prefix, max_tf, original, latest) do
    {:ok, file} = File.open("#{file_prefix}segments.csv", [:write, :utf8])
    RoadMap.edges(map)
    |> Enum.each(&write_single_segment(&1, file, max_tf, original, latest))
    File.close(file)
  end

  defp write_junction(map, file_prefix, max_tf, original, latest) do
    {:ok, file} = File.open("#{file_prefix}junctions.csv", [:write, :utf8])
    RoadMap.edges(map)
    |> Enum.each(&write_single_junction(&1, map, file, max_tf, original, latest))
    File.close(file)
  end

  defp write_single_segment({from, to, length, type}, file, max_tf, original, latest) do
    IO.write file, "#{inspect from},#{inspect to},#{length},#{type}"
    write_cars(file, max_tf, original.segment, from, to)
    write_cars(file, max_tf, latest.segment, from, to)
    IO.write file, "\n"
  end

  defp write_single_junction({from, via, _length, _type}, map, file, max_tf, original, latest) do
    type = RoadMap.vertex_type(map, via)
    IO.write file, "#{inspect from},#{inspect via},#{type}"
    write_cars(file, max_tf, original.junction, from, via)
    write_cars(file, max_tf, latest.junction, from, via)
    IO.write file, "\n"
  end

  defp write_cars(file, max_tf, table, from, to) do
    #Prepends all numbers by comma
    last = :ets.match(table, {{from, to, '$1'}, '$2'})
    |> Enum.reduce(-1, fn
      ([tf, count], prev)
        when prev + 1 == prev ->
          IO.write file, ",#{count}"
          tf
      ([tf, count], prev) -> #Add zeroes into empty places
          IO.write file, String.duplicate(",0", tf - prev - 1)
          IO.write file, ",#{count}"
          tf
    end)

    IO.write String.duplicate(",0", max_tf - last)
  end

#Calculate delay
  def calculate_delay(%Aggregator{segments: segments, junctions: junctions, global: global}) do
    Oracle.reset_current(global.oracle)

    s = Task.async fn ->
      get_grouped_resource(segments) #Get segments grouped by {from, to}
      |> Stream.chunk(50, 50, []) #Create meaningful chunks
      |> Stream.map(&Task.async(fn -> current_segment(&1, global) end)) #Start all as async tasks
      |> Enum.reduce(nil, fn (t, _) -> Task.await(t) end) #Wait for all tasks to finish
    end

    j = Task.async fn ->
      get_grouped_resource(junctions) #Get junctions grouped by {from, to}
      |> Stream.chunk(50, 50, []) #Create meaningful chunks
      |> Stream.map(&Task.async(fn -> current_junction(&1, global) end)) #Start all as async tasks
      |> Enum.reduce(nil, fn (t, _) -> Task.await(t) end) #Wait for all tasks to finish
    end

    Task.await(s)
    Task.await(j)
  end

#Get resource grouped by same {from, to}
  defp get_grouped_resource(table) do
    get_resource(table, 1)
    |> Stream.chunk_by(fn({{from, to, _tf}, _count}) -> {from, to} end)
  end

  defp get_resource(table, limit) do
    Stream.resource fn -> :ets.match(table, :'$1', limit) end,
      fn
        :"$end_of_table" -> {:halt, nil}
        {[match], cont} -> {match, :ets.match(cont)}
        {matches, cont} -> {matches, :ets.match(cont)}
      end,
      fn _ -> nil end
  end

  defp current_junction(chunk, global) do
    for single <- chunk do
      {from, to, dict} = single_to_dict(single)
      r = Delay.junction(global, from, to, dict)
      Oracle.current_delay_result(global.oracle, :junction, from, to, r)
    end
  end

  defp current_segment(chunk, global) do
    for single <- chunk do
      {from, to, dict} = single_to_dict(single)
      r = Delay.segment(global, from, to, dict)
      Oracle.current_delay_result(global.oracle, :segment, from, to, r)
    end
  end

#Convert enum of single values into Dict for Delay
  defp single_to_dict(single) do
    {{from, to, _tf}, _count} = hd(single)
    dict = Enum.into(single, %{}, fn {{_from, _to, tf}, count} -> {tf, count} end)
    {from, to, dict}
  end

  def compare(%Aggregator{} = current, %Aggregator{} = previous) do
    s = compare_tables(current.segments, previous.segments)
    j = compare_tables(current.junctions, previous.junctions)
    s and j
  end

  defp compare_tables(t1, t2) do
    #Represent both tables as sources - with chunks of 50 elements each
    s1 = get_resource(t1, 50)
    s2 = get_resource(t2, 50)

    res = Stream.zip(s1, s2) #Zip them
    |> Stream.drop_while(fn {l1, l2} -> l1 == l2 end) #Drop until same
    |> Stream.take(1) #Take single element
    |> Enum.to_list #If tables where the same, drop_while removed the whole list

    res == []
  end
end
