defmodule Planner do
  defstruct map: nil, oracle: nil

  defmodule VertexData do
    defstruct visited: false, time: 0, vertexTime: 0, edgeTime: 0, previous: nil
  end

  def new(map, oracle) do
    %Planner{map: map, oracle: oracle}
  end

  def route(planner, from, to) do
    #Format: vertex -> VertexData
    vertices = HashDict.new()
    vertices = Dict.put_new(vertices, from, %VertexData{})

    #Priority queue only stores values, not tuples with identificator
    #Format: time -> [ vertex ]
    times = HashDict.new()
    times = Dict.put_new(times, 0, [from])

    #Priority queue, just times in it
    queue = :heaps.new()
    queue = :heaps.add(0, queue)
    
    #Find route by running Dijkstra
    vertices = dijkstra(planner, to, vertices, times, queue)
  
    #Build route plan
    p = Plan.new(from, to, Dict.get(vertices, to).time)
    plan(p, to, vertices)
  end

#Main loop = queue extraction
  defp dijkstra(planner, to, vertices, times, queue) do
    time = :heaps.min(queue)
    current = Dict.get(times, time)

#There is no option to delete data from the minheap, so filter out already visited nodes
    current = Enum.filter(current, fn (v) -> not Dict.get(vertices, v).visited end)

    {vertices, times, queue, found} = handleDistance(planner, to, current, vertices, times, queue)
    if found do
      vertices
    else
      dijkstra(planner, to, vertices, times, :heaps.delete_min(queue))
    end
  end

#Find all neighbours for given vertex and call handleNeighbours. Stop if me == to
  defp handleDistance(_planner, _to, [], vertices, times, queue) do
    {vertices, times, queue, false}
  end

  defp handleDistance(planner, to, [me | rest], vertices, times, queue) do
    vertex = Dict.get(vertices, me)

    #Set as visited
    vertex = %VertexData{ vertex | visited: true }
    vertices = Dict.put(vertices, me, vertex)

    if me == to do
      {vertices, times, queue, true}
    else
      outgoing = RoadMap.edges(planner.map, me)
      {vertices, times, queue} = handleNeighbours(planner, vertex, outgoing, vertices, times, queue)
      handleDistance(planner, to, rest, vertices, times, queue)
    end
  end

#For each neighbour, calculate their vertex and edge time and update vertices and queue if needed.
  defp handleNeighbours(_planner, _vertex, [], vertices, times, queue) do
    {vertices, times, queue}
  end

  defp handleNeighbours(planner, vertex, [{me, to, _roadDistance} | rest], vertices, times, queue) do
    toVertex = Dict.get(vertices, to)
    if toVertex == nil or not toVertex.visited do
#Count both vertex time and edge time
      vertexTime = Oracle.vertex_time(planner.oracle, vertex.previous, me, to, vertex.time)
      edgeTime = Oracle.edge_time(planner.oracle, me, to, vertex.time)

      totalTime = vertexTime + edgeTime + vertex.time

#This new route is shorter
      if toVertex == nil or totalTime < toVertex.time do
        vertices = Dict.put(vertices, to, %VertexData{ 
            visited: false,
            time: totalTime,
            vertexTime: vertexTime,
            edgeTime: edgeTime,
            previous: me
          })
        if not Dict.has_key?(times, totalTime) do
          queue = :heaps.add(totalTime, queue)
        end
        times = Dict.update(times, totalTime, [to], fn x -> [to] ++ x end)
      end
    end
    handleNeighbours(planner, vertex, rest, vertices, times, queue)
  end

#Build Plan from vertices
  defp plan(p, current, vertices) do
    v = Dict.get(vertices, current)
    p = Plan.prependStep(p, current, v.edgeTime, v.vertexTime)
    if v.previous == p.from do
      p
    else
      plan(p, v.previous, vertices)
    end
  end
end


