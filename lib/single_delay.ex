defmodule SingleDelay do

  def segment_calc_fn(global, from, to) do
    map = global.map

    length = RoadMap.length(map, from, to)
    type = 1 #TODO
    &(segment_calculation(global.tf_duration, &1, length, type))
  end

  def segment(global, number_of_cars, from, to) do
    calc_fn = segment_calc_fn(global, from, to)
    {_speed, duration} = calc_fn.(number_of_cars)
    duration
  end

  def segment_calculation(tf_duration, number_of_cars, length, type) do
#From table
    types = %{
#Free flow speed, capacity
      1 => {80, 1850},
      2 => {65, 1800},
      3 => {55, 1750},
      4 => {45, 1700}
    }
    
    {vf, c} = types[type]
    q = number_of_cars * 3600 / tf_duration #veh/hour 

    #Constants
    x0 = 0.5
    tf = 0.25
    k = 2.31

    #Optimization
    q_c = q / c
    q_c_1 = q_c - 1

    #MAGIC
    speed = vf / 
      (1 + 0.25 * vf * tf *
       ( q_c_1 + :math.sqrt( q_c_1 * q_c_1 + 8*k*(q_c - x0)/(c*tf) ) )
      )

    time_in_hours = length / speed
    {speed, time_in_hours * 3600}
  end

  def junction_calc_fn(global, _from, _via) do
    type = 1 #TODO
    &(junction_calculation(global.tf_duration, &1, type))
  end

  def junction(global, number_of_cars, from, via) do
    calc_fn = junction_calc_fn(global, from, via)
    calc_fn.(number_of_cars)
  end

  def junction_calculation(tf_duration, number_of_cars, type) do
    types = %{
#Capacity, cycle time, green time
      1 => {1800, 60, 30},
      2 => {1850, 60, 30},
    }

    {capacity, cycle, green} = types[type]

    ti = 3600 / tf_duration
    capacity = capacity / ti
    t = 1 / ti

    x0 = 0.8
    k = 1
    x = number_of_cars / capacity
    u = green / cycle

    d1 = if x > 1 do
      0.5 * (cycle - green)
    else
      0.5 * cycle * (1 - u) * (1 - u) / (1 - u*x)
    end

    if x >= x0 do
      d21 = 900*t*(-(x-1) + :math.sqrt( (x-1)*(x-1) + 8*k*(x-x0)/(capacity*t) ) )
      d22 = 1800*(x-1)*t
      d2 = d21 + d22
    else
      d2 = 0
    end
    
    d1 + d2
  end
end


