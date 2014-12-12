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

  def junction(_global, _number_of_cars, _from, _via) do
    61
  end
end


