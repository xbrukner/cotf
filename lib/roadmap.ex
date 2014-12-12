defmodule RoadMap do
  defstruct map: nil



  def new(filename) do
    File.read!(filename)
      |> parser
  end

  defp parser(data) do
    parser(String.split(data, "\n"), %RoadMap{map: :digraph.new}, :vertices)
  end

  defp parser(["" | rest], state, :vertices) do
    parser(rest, state, :edges)
  end

  defp parser([v | rest], state, :vertices) do
    #TODO - coordinates in the future
    :digraph.add_vertex(state.map, v) 
    parser(rest, state, :vertices)
  end

#From vertices to edges
  defp parser(["" | rest], state, :edges) do
    state
  end

  defp parser([e | rest], state, :edges) do
    data = String.split(e, " ")
    [from, to, length] = Enum.take(data, 3)
    :digraph.add_edge(state.map, from, to, length)
    if Enum.count(data) == 3 do #Two way
      :digraph.add_edge(state.map, to, from, length)
    end
    parser(rest, state, :edges)
  end

  defp parser(_, state, _) do
    state
  end

  def vertices(map) do
    :digraph.vertices(map.map)
  end

  def edges(map) do
    :digraph.edges(map.map)
  end

  def edges(map, from) do
    :digraph.out_edges(map.map, from)
      |> Enum.map(fn e -> 
          {_edge, from, to, length} = :digraph.edge(map.map, e) 
          {from, to, length}
        end)
  end

  def length(map, from, to) do
    RoadMap.edges(map, from) #Outgoing
      |> Enum.find(fn ({_f, t, _l}) -> t == to end) #Find this one
      |> elem(2) #Extract length
      |> Float.parse #Parse to {float, rest}
      |> elem(0) #Choose float
  end
end


