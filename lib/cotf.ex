defmodule Cotf do
  def main(args) do
    [map_file, cars] = args
    {cars, _} = Integer.parse(cars)
    puts "Cache of the Future"
    puts "Reading map #{map_file}... "
    map = RoadMap.new(map_file)
    puts "done!"

    puts " Vertices: " <> to_string(Enum.count(RoadMap.vertices(map)))
    puts " Edges: " <> to_string(Enum.count(RoadMap.edges(map)))
    puts " Starting and ending: " <> to_string(Dict.size(RoadMap.get_start_end_vertices(map)))
    
    puts "Using timeframe of 60 seconds"
    global = %Global{map: map, tf_duration: 60}
    global = %Global{ global | oracle: Oracle.new(global) }
    global = %Global{ global | planner: Planner.new(global), aggregator: Aggregator.new(global) }

    puts "Calculating default distances..."
    Oracle.calculate_default(global.oracle)
    puts "done!"

    {a1, a2, a3} = {1418, 834397, 523198}#:erlang.now()
    :random.seed(a1, a2, a3)
    puts "Using seed {#{a1}, #{a2}, #{a3}}"
    puts "Generating #{cars} random cars within next hour..."

    points = RoadMap.get_start_end_vertices(map)
    seconds_in_hour = 3600
    
    car_objects = gen_cars(global, points, seconds_in_hour, cars)
    puts "done!"

    puts "Starting cycling..."
    cycle(global, car_objects)
    puts "done!"
    
    original = fixpoint_plan(global, car_objects, :original)
    latest = fixpoint_plan(global, car_objects, :latest)
    #TODO - update times for original plan and last plan, calculate aggregation

    file_prefix = time_prefix()
    puts "Saving output with #{file_prefix} prefix..."
    output_cars(file_prefix, car_objects)
    output_aggregation(file_prefix, original, latest, global)
    puts "done!"
  end

  defp gen_cars(global, points, end_time, number) do
    gen_cars(global, points, Dict.size(points), end_time, number, [])
  end

  defp gen_cars(_global, _points, _num_points, _end_time, remaining, acc)
    when remaining == 0 do
    acc
  end

  defp gen_cars(global, points, num_points, end_time, remaining, acc) do
    {p1, p2} = rand_points(num_points)
    from = points[p1]
    to = points[p2]

    start = :random.uniform(end_time) - 1
    car = Car.new(from, start, to, global)
    gen_cars(global, points, num_points, end_time, remaining - 1, [car] ++ acc)
  end

  defp rand_points(num_points) do
    rand_points(num_points, :random.uniform(num_points) - 1, :random.uniform(num_points) - 1)
  end

  defp rand_points(num_points, p1, p2)
    when p1 == p2 do
    rand_points(num_points)
  end

  defp rand_points(_num_points, p1, p2) do
    {p1, p2}
  end

  defp cycle(global, car_objects) do
    cycle(global, car_objects, 1, nil)
  end

  defp cycle(global, car_objects, iteration, l_info) do
    puts " Starting iteration #{iteration}..."
    calculate_plan(car_objects, iteration <= 2)
    {same, info} = aggregate_compare(global, l_info)
    if same do
      puts " done iterating!"
    else
      calculate_durations(global)
      puts " done!"
      cycle(global, car_objects, iteration + 1, info)
    end
  end

  defp aggregate_compare(global, nil) do
    {false, Aggregator.get_info(global.aggregator) }
  end

  defp aggregate_compare(global, info) do
    {Aggregator.compare(global.aggregator, info), Aggregator.get_info(global.aggregator)}
  end

  defp aggregate_list_info(global) do
    Aggregator.get_info(global.aggregator)
  end

  defp calculate_durations(global) do
    puts "  Calculating durations..."
    Aggregator.calculate_delay(global.aggregator)
    puts "  done!"
  end

  defp calculate_plan(car_objects, all) do
    puts "  Calculating plan..."
    c = Counter.Waiter.new()
    for car <- car_objects do
      if all or :random.uniform(40) == 1 do
        Counter.Waiter.spawn c, fn ->
          Car.calculate_plan(car)
          Car.send_plan(car)
        end
      end
    end
    Counter.Waiter.all_started(c)
    Counter.Waiter.wait_for(c)
    puts "  done!"
  end

  defp time_prefix() do
    {{_y, month, d}, {h,m,s}} = :calendar.local_time()
    "result #{d}.#{month}. #{h}:#{m}:#{s} "
  end

  defp output_cars(file_prefix, car_objects) do
    {:ok, file} = File.open("#{file_prefix}cars.csv", [:write, :utf8])
    for car <- car_objects do
      IO.puts file, Car.result(car)
    end
    File.close(file)
  end

  defp output_aggregation(file_prefix, original, latest, global) do
    max_tf = Aggregator.write_results(global.map, file_prefix, original, latest)
    puts " Maximal time frame: #{max_tf}"
  end

  defp fixpoint_plan(global, car_objects, type) do
    global2 = %Global{map: global.map, tf_duration: 60, oracle: global.oracle}
    global2 = %Global{ global2 | aggregator: Aggregator.new(global2) }
    Oracle.reset_current(global.oracle)
    puts "Calculating fixpoint for plan #{type}"
    aggregation_info = fixpoint_plan2(global2, car_objects, type, 0, [] )
    aggregation_info
  end

  defp fixpoint_plan2(global, car_objects, type, iteration, l_infos) do
    puts " Iteration #{iteration}"
    car_fixpoint_plan(global, car_objects, type)
    info = aggregate_list_info(global)
    if info in l_infos do
      IO.puts "done!"
      info
    else
      if iteration == 100 do
        IO.puts "done! (100)"
        info
      else
        Aggregator.calculate_delay(global.aggregator)
        fixpoint_plan2(global, car_objects, type, iteration + 1, [info] ++ l_infos)
      end
    end
  end

  defp car_fixpoint_plan(global, car_objects, type) do
    c = Counter.Waiter.new()
    for car <- car_objects do
      Counter.Waiter.spawn c, fn ->
        Car.fixpoint_plan(car, global, type)
      end
    end
    Counter.Waiter.all_started(c)
    Counter.Waiter.wait_for(c)
  end

  defp puts(text) do
    Logger.log(:info, text)
  end
end
