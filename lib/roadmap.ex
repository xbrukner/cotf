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
    label = 1 #Type
    :digraph.add_vertex(state.map, v, label) 
    parser(rest, state, :vertices)
  end

#From vertices to edges
  defp parser(["" | _rest], state, :edges) do
    state
  end

  defp parser([e | rest], state, :edges) do
    data = String.split(e, " ")
    [from, to, length] = Enum.take(data, 3)
    label = {length, 1} #1 = Type
    :digraph.add_edge(state.map, from, to, label)
    if Enum.count(data) == 3 do #Two way
      :digraph.add_edge(state.map, to, from, label)
    end
    parser(rest, state, :edges)
  end

  defp parser(_, state, _) do
    state
  end

  def vertices(%RoadMap{} = map) do
    :digraph.vertices(map.map)
  end

  def edges(%RoadMap{} = map) do
    :digraph.edges(map.map)
  end

  def edges(%RoadMap{} = map, from) do
    :digraph.out_edges(map.map, from)
      |> Enum.map(fn e -> 
          {_edge, from, to, {length, type}} = :digraph.edge(map.map, e) 
          {from, to, length, type}
        end)
  end

  def length_type(%RoadMap{} = map, from, to) do
    {_from, _to, length, type} = RoadMap.edges(map, from) #Outgoing
      |> Enum.find(fn ({_f, t, _l, _t}) -> t == to end) #Find this one
    length = Float.parse(length) #Parse to {float, rest}
      |> elem(0) #Choose float
    {length, type}
  end

  def vertex_type(%RoadMap{} = map, vertex) do
    :digraph.vertex(map.map, vertex)
      |> elem(1)
  end
end


