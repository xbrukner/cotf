defmodule Oracle do
  defstruct map: nil

  def new(map) do
    %Oracle{map: map}
  end

  def edge_time(%Oracle{map: map}, from, to, _timeframe) do
    RoadMap.edges(map, from)
      |> Enum.find(fn {_f, t, _l} -> t == to end)
      |> elem(2)
      |> String.to_integer
  end

  def vertex_time(_map, _from, _via, _to, _timeframe) do
    #TODO
    0
  end
end

