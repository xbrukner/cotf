defmodule SingleDelay do

  def segment(global, _number_of_cars, from, to) do
    map = global.map

    length = RoadMap.edges(map, from) #Outgoing
      |> Enum.find(fn ({_f, t, _l}) -> t == to end) #Find this one
      |> elem(2) #Extract length
      |> Float.parse #Parse to {float, rest}
      |> elem(0) #Choose float

    fs = 80 #Free flow speed - kph
#capacity = 1850
    #MAGIC

    time_in_hours = length / fs
    time_in_hours * 3600
  end

  def junction(_global, _number_of_cars, _from, _via, _to) do
    0
  end
end


