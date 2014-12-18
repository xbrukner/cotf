defmodule Delay do
#Junctions
  def junction(global, from, via, cars) do
    cars = Enum.filter cars, fn {_, v} -> v > 0 end
    delayfn = &(SingleDelay.junction(global, &1, from, via))
    durations = Enum.map(cars, fn({tf, cars}) -> {tf, delayfn.(cars)} end)

    reducefn = &(junction(global.tf_duration, &1, &2))
    Enum.reduce(durations, { {-1, 0}, %{} }, reducefn)
      |> elem(1)
  end

  defp junction(tf_duration, {tf, duration}, { {last_tf, last_delay}, res}) do
    overflow = last_delay - (tf - last_tf) * tf_duration
    altered_duration = duration + if overflow > 0 do overflow else 0 end
    
    { {tf, altered_duration}, Dict.put_new(res, tf, altered_duration) }
  end

#Segments
  def segment(global, from, to, cars) do
    cars = Enum.filter cars, fn {_, v} -> v > 0 end
    calcfn = SingleDelay.segment_calc_fn(global, from, to)
    speeds_times = Enum.map(cars, fn({tf, cars}) -> {tf, {cars, calcfn.(cars)} } end)
#IO.inspect speeds_times
    {length, _} = RoadMap.length_type(global.map, from, to)

    #Constants
    car_length = 0.0045 #km
    safe_distance = 1 # seconds
    reducefn = &(segment(global.tf_duration, length, {car_length, safe_distance}, &1, &2))
    Enum.reduce(speeds_times, { {-1, -1, 0, [] }, %{} }, reducefn)
      |> elem(1)
  end

# speeds = (km/h, km, seconds) that the car will cover
  defp segment(tf_duration, length, constants, {tf, {cars, {speed, time}}}, { {l_start_time, l_finish_time, l_group_length, l_speeds}, res}) do
    start_time = tf * tf_duration
    finish_time_f = start_time + time #Finish time of first car
    if finish_time_f >= l_finish_time do
      speeds = [{speed, length, time}]
      total_time = time
    else
      start_time_diff = start_time - l_start_time
      true = Enum.count(l_speeds) > 0
      {first_car_distance, l_speeds_remaining} = distance_from_speeds(l_speeds, start_time_diff)
      true = Enum.count(l_speeds_remaining) > 0
#IO.inspect {"first_car_distance", first_car_distance, "l_speeds_remaining", l_speeds_remaining}
      speeds = catch_up_start(first_car_distance, l_group_length, l_speeds_remaining, speed)
        |> extend_last_speed(length)

      total_time = Enum.reduce(speeds, 0, fn ({_s, _l, t}, acc) -> t + acc end)
      ^length = Enum.reduce(speeds, 0, fn ({_, l, _}, acc) -> l + acc end)
    end
    my_group_length = group_length(cars, speeds, constants) 
    end_group_time = my_group_length / last_speed(speeds) * 3600
    finish_time_l = start_time + total_time + end_group_time
#IO.inspect {"finish_time_l", finish_time_l, start_time + total_time, my_group_length, end_group_time, speed, total_time, total_time + end_group_time / 2, speeds}
    { {start_time, finish_time_l, my_group_length, speeds }, 
        Dict.put_new(res, tf, total_time + end_group_time / 2) }
  end

#Calculate initial speed of group (for safe distance)
  defp initial_speed([{0, _, _} | [{s, _, _} | _] ]) do
    s
  end

  defp initial_speed([{s, _, _} | _ ]) do
    s
  end

  defp last_speed(speeds) do
    List.last(speeds)
    |> elem(0)
  end

  defp group_length(number_of_cars, speeds, {car_length, safe_distance_time}) do
    number_of_cars * car_length + number_of_cars * initial_speed(speeds) * safe_distance_time / 3600
  end

#Calculate time to cover certain distance when doing this speed
  defp time_to_cover_distance(distance, speeds) do
    time_to_cover_distance(distance, speeds, 0)
  end

#Distance can be larger than in speeds, if so use the last one (in very very long queue)
  defp time_to_cover_distance(distance, [ {speed, length, time} | [] ], total)
    when distance > length do
    {total + time + (distance - length) / speed * 3600, [ {speed, 0, 0} ] }
  end

#Rest in this speed
  defp time_to_cover_distance(distance, [ {speed, length, _time} | rest ], total)
    when distance < length do
    {total + distance / speed * 3600, [{speed, length - distance, (length - distance) / speed * 3600}] ++ rest}
  end

#Not enough in this speed
  defp time_to_cover_distance(distance, [ {_, length, time} | rest ], total) do
    time_to_cover_distance(distance - length, rest, total + time)
  end

#Extend the last speed so the overall length holds
  defp extend_last_speed(l_speeds, segment_length) do
#IO.inspect l_speeds
    extend_last_speed(segment_length, l_speeds, 0, [])
  end
  
  defp extend_last_speed(segment_length, [{speed, length, _}], total_length, reversed) do
    true = segment_length >= total_length + length #assert
    [ {speed, segment_length - total_length, (segment_length - total_length) / speed * 3600} ] ++ reversed
      |> Enum.reverse
  end

  defp extend_last_speed(segment_length, [{_, length, _} = el | rest], total_length, reversed) do
    extend_last_speed(segment_length, rest, total_length + length, [el] ++ reversed)
  end


# In catch_up_start, 4 situations may happen:
# 1) Previous group did not even start (leave the beginning of the segment)
# 2) Previous group did start, but the end did not manage to start
# 3) Previous group did start and the end has just started
# 4) Previous group did start as whole
# Tests used:
# in remaining speeds, first speed is still zero -> 1)
# distance covered by first < length of group -> 2)
# distance covered by first car = length of group -> 3)
# otherwise -> 4)

#Previous group waited and did not finish leaving start -> update waiting time
  defp catch_up_start(first_car_distance, l_group_length, [ {0, _length, _time} | _l_rest ] = l_speeds_remaining, _my_speed) do
#IO.puts "1)"
    ^first_car_distance = 0.0 #assert
    { time, l_speeds } = time_to_cover_distance(l_group_length, l_speeds_remaining)
    [ {0, 0, time} ] ++ l_speeds
  end

#Previous group did not finish leaving start -> introduce delay
  defp catch_up_start(first_car_distance, l_group_length, l_speeds_remaining, _my_speed)
    when first_car_distance < l_group_length do
#   IO.puts "2)"
    { time, l_speeds } = time_to_cover_distance(l_group_length - first_car_distance, l_speeds_remaining)
    [ {0, 0, time} ] ++ l_speeds
  end

#Previous group waited, started and just finished leaving start -> new group is same as old (avoid zero waiting time)
  defp catch_up_start(first_car_distance, l_group_length, l_speeds_remaining, _my_speed)
    when first_car_distance == l_group_length do
    IO.puts "3)"
    l_speeds_remaining
  end

#Previous group left start -> introduce covered time and distance and catch up on the run
defp catch_up_start(first_car_distance, l_group_length, l_speeds_remaining, my_speed)
    when first_car_distance - l_group_length > 0 do
#IO.inspect {first_car_distance, first_car_distance - l_group_length, my_speed, Enum.take(l_speeds_remaining, 1)}
    catch_up(first_car_distance - l_group_length, l_speeds_remaining, my_speed, 0)
  end

#Catch up happens during this speed, but after the first car finishes (and therefore speeds end)
  defp catch_up(remaining_distance, [{speed, _length, _time} | []], my_speed, covered_time) do
    time_in_my_speed = remaining_distance / (my_speed - speed) * 3600
    total_distance_in_my_speed = my_speed * (time_in_my_speed + covered_time) / 3600

    [ {my_speed, total_distance_in_my_speed, time_in_my_speed + covered_time} ] ++
      [ {speed, 0, 0} ]
  end

#Next group did not reach previous with this speed -> add covered distance and time
  defp catch_up(remaining_distance, [{speed, _length, time} | l_rest], my_speed, covered_time) 
    when remaining_distance > (my_speed - speed) * time / 3600  do
    catch_up(remaining_distance - (my_speed - speed) * time / 3600, l_rest, my_speed, time + covered_time)
  end

#Next group did reach previous with this speed
  defp catch_up(remaining_distance, [{speed, _length, time} | l_rest], my_speed, covered_time)
    when remaining_distance <= (my_speed - speed) * time / 3600 do
    time_in_my_speed = remaining_distance / (my_speed - speed) * 3600
    total_distance_in_my_speed = my_speed * (time_in_my_speed + covered_time) / 3600

    time_in_speed = time - time_in_my_speed
    distance_in_speed = speed * time_in_speed / 3600

    [ {my_speed, total_distance_in_my_speed, time_in_my_speed + covered_time} ] ++
      [ {speed, distance_in_speed, time_in_speed} ] ++ l_rest
  end

#Given speeds, what distance is covered during time_diff & adjusted speeds
  defp distance_from_speeds(speeds, time_diff) do
    distance_from_speeds(speeds, time_diff, 0)
  end

#Remaining time is spent in this segment
  defp distance_from_speeds([{speed, _length, time} | r_speeds], time_diff, distance)
    when time_diff <= time do
    {distance + (speed * time_diff / 3600), [{speed, speed * (time - time_diff) / 3600, time - time_diff}] ++ r_speeds}
  end

#Not all time is spent in this segment
  defp distance_from_speeds([{_speed, length, time} | r_speeds], time_diff, distance) do
    distance_from_speeds(r_speeds, time_diff - time, distance + length)
  end

end

