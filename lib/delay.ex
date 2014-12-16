defmodule Delay do
#Junctions
  def junction(global, from, via, cars) do
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
    calcfn = SingleDelay.segment_calc_fn(global, from, to)
    speeds_times = Enum.map(cars, fn({tf, cars}) -> {tf, {cars, calcfn.(cars)} } end)
    {length, _} = RoadMap.length_type(global.map, from, to)

    #Constants
    car_length = 0.0045 #km
    safe_distance = 1 # seconds
    reducefn = &(segment(global.tf_duration, length, {car_length, safe_distance}, &1, &2))
    Enum.reduce(speeds_times, { {-1, -1, 0, [] }, %{} }, reducefn)
      |> elem(1)
  end

# speeds = (km/h, km, seconds) that the car will cover
  defp segment(tf_duration, length, constants, {tf, {cars, {speed, time}}}, { {l_start_time, l_finish_time, l_cars, l_speeds}, res}) do
    start_time = tf * tf_duration
    finish_time = start_time + time
    if finish_time > l_finish_time do
      { {start_time, finish_time, cars, [{speed, length, time}] }, Dict.put_new(res, tf, time) }
    else
      speeds = catching_up(start_time - l_start_time, constants, speed, l_cars, l_speeds)
      total_time = Enum.reduce(speeds, 0, fn ({_s, _l, t}, acc) -> t + acc end)
      { {start_time, start_time + total_time, cars, speeds}, Dict.put_new(res, tf, total_time) }
    end
  end

#TODO - calculate queue_length on final speed to set final time as time when the end of queue exits the segment
#defp queue_length({car_length, safe_distance}, cars, safe_distance) do

  defp catching_up(time_difference, {car_length, safe_distance}, speed, l_cars, l_speeds) do
#Difference in initial distance
    distance = distance_from_speeds(l_speeds, time_difference) - car_length * l_cars # - queue length
    catching_up_distance(distance, safe_distance, speed, l_cars, l_speeds)
  end

#Cathing up when knowing distance
  defp catching_up_distance(distance_to_cover, safe_distance, speed, l_cars, l_speeds) do
    catching_up_distance(safe_distance, speed, l_cars, l_speeds, distance_to_cover, 0, 0)
  end

#Finished in this segment
  defp catching_up_distance(safe_distance, m_speed, l_cars, [{speed, length, time} | r_speeds], distance_to_cover, first_time, first_distance)
    when (m_speed - speed) * time / 3600 >= distance_to_cover - speed * l_cars * safe_distance / 3600 do

    remaining_distance_to_cover = distance_to_cover - speed * l_cars * safe_distance / 3600
    added_time = remaining_distance_to_cover / (m_speed - speed) * 3600
    total_distance = (first_time + added_time) / 3600 * m_speed

    remaining_length = length - (total_distance - first_distance)
    remaining_current = if remaining_length > 0 do
      [ {speed, remaining_length, remaining_length / speed * 3600} ]
    else 
      []
    end


    [ {m_speed, total_distance, first_time + added_time} ] ++
      remaining_current ++ r_speeds
  end

  defp catching_up_distance(safe_distance, m_speed, l_cars, [{speed, length, time} | r_speeds],distance_to_cover,  first_time, first_distance) do
    catching_up_distance(safe_distance, m_speed, l_cars, r_speeds, distance_to_cover - (m_speed - speed) * time / 3600, first_time + time, first_distance + length) 
  end


  defp distance_from_speeds(l_speeds, time_diff) do
    distance_from_speeds(l_speeds, time_diff, 0)
  end

#Remaining time is spent in this segment
  defp distance_from_speeds([{speed, _length, time} | _r_speeds], time_diff, distance)
    when time_diff <= time do
    distance + (speed * time_diff / 3600)
  end

#Not all time is spent in this segment
  defp distance_from_speeds([{_speed, length, time} | r_speeds], time_diff, distance) do
    distance_from_speeds(r_speeds, time_diff - time, distance + length)
  end


#Spawning
  def spawn_junction(global, from, via, cars, result_fn, counter) do
    spawn fn ->
      cars = Enum.filter cars, fn {_, v} -> v > 0 end
      junction(global, from, via, cars)
        |> result_fn.()
      Counter.finished(counter)
    end
  end

  def spawn_segment(global, from, to, cars, result_fn, counter) do
    spawn fn ->
      cars = Enum.filter cars, fn {_, v} -> v > 0 end
      segment(global, from, to, cars)
        |> result_fn.()
      Counter.finished(counter)
    end
  end
end

