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

  defp parser([v | rest], state, :vertices) do
    #TODO - coordinates in the future
    :digraph.add_vertex(state.map, v) 
    parser(rest, state, :vertices)
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
    map.map.vertices()
  end

  def edges(map) do
    map.map.edges()
  end
end


