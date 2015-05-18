defmodule Planner do
  defstruct map: nil, oracle: nil

  defmodule Resource do
    defstruct vertices: nil, times: nil

    def new() do
      %Resource{
        vertices: :ets.new(Resource, [:set, :public]),
        times: :ets.new(Resource, [:bag, :public])
      }
    end

    def clear(%Resource{vertices: v, times: t}) do
      :ets.delete_all_objects(v)
      :ets.delete_all_objects(t)
    end

    def delete(%Resource{vertices: v, times: t}) do
      :ets.delete(v)
      :ets.delete(t)
    end

    def put_vertex(%Resource{vertices: v} = r, from, data) do
      :ets.insert(v, {from, data})
      r
    end

    def get_vertex(%Resource{vertices: v}, which) do
      case :ets.select(v, [{{which, :'$1'}, [], [:'$1']}]) do
        [match] -> match
        []      -> nil
      end
    end

    def put_time(%Resource{times: t} = r, time, vertex) do
      :ets.insert(t, {time, vertex})
      r
    end

    def get_time(%Resource{times: t}, time) do
      :ets.select(t, [{{time, :'$1'}, [], [:'$1']}])
    end

    def time_exists?(%Resource{} = r, time) do
      [] != get_time(r, time)
    end
  end

  defmodule VertexData do
    #All times are absolute
    defstruct visited: false, time: 0, vertexTime: 0, edgeTime: 0, previous: nil
  end

  def new(%Global{} = g) do
    %Planner{map: g.map, oracle: g.oracle}
  end

  def new(map, oracle) do
    %Planner{map: map, oracle: oracle}
  end

  def route(planner, %Resource{} = resource, from, to, start_time) do
    #Format: vertex -> VertexData
    resource = Resource.put_vertex(resource, from, %VertexData{time: start_time})

    #Priority queue only stores values, not tuples with identificator
    #Format: time -> [ vertex ]
    resource = Resource.put_time(resource, start_time, from)

    #Priority queue, just times in it
    queue = :heaps.new()
    queue = :heaps.add(start_time, queue)

    #Find route by running Dijkstra
    resource = dijkstra(planner, to, resource, queue)

    #Build route plan
    p = Plan.new(from, to, Resource.get_vertex(resource, to).time - start_time)
    plan(p, to, resource)
  end

#Main loop = queue extraction
  defp dijkstra(planner, to, resource, queue) do
    time = :heaps.min(queue)
    current = Resource.get_time(resource, time)

#There is no option to delete data from the minheap, so filter out already visited nodes
    current = Enum.filter(current, fn (v) -> not Resource.get_vertex(resource, v).visited end)

    {resource, queue, found} = handleDistance(planner, to, current, resource, queue)
    if found do
      resource
    else
      dijkstra(planner, to, resource, :heaps.delete_min(queue))
    end
  end

#Find all neighbours for given vertex and call handleNeighbours. Stop if me == to
  defp handleDistance(_planner, _to, [], resource, queue) do
    {resource, queue, false}
  end

  defp handleDistance(planner, to, [me | rest], resource, queue) do
    vertex = Resource.get_vertex(resource, me)

    #Set as visited
    vertex = %VertexData{ vertex | visited: true }
    resource = Resource.put_vertex(resource, me, vertex)

    if me == to do
      {resource, queue, true}
    else
      outgoing = RoadMap.edges(planner.map, me)
      {resource, queue} = handleNeighbours(planner, vertex, outgoing, resource, queue)
      handleDistance(planner, to, rest, resource, queue)
    end
  end

#For each neighbour, calculate their vertex and edge time and update vertices and queue if needed.
  defp handleNeighbours(_planner, _vertex, [], resource, queue) do
    {resource, queue}
  end

  defp handleNeighbours(planner, vertex, [{me, to, _roadDistance, _type} | rest], resource, queue) do
    toVertex = Resource.get_vertex(resource, to)
    if toVertex == nil or not toVertex.visited do
#Count both vertex time and edge time
      vertexTime = Oracle.vertex_time(planner.oracle, vertex.previous, me, vertex.time)
      edgeTime = Oracle.edge_time(planner.oracle, me, to, vertex.time)

      totalTime = vertexTime + edgeTime + vertex.time

#This new route is shorter
      if toVertex == nil or totalTime < toVertex.time do
        resource = Resource.put_vertex(resource, to, %VertexData{
            visited: false,
            time: totalTime,
            vertexTime: vertexTime + vertex.time,
            edgeTime: edgeTime + vertex.time + vertexTime,
            previous: me
          })
        if not Resource.time_exists?(resource, totalTime) do
          queue = :heaps.add(totalTime, queue)
        end
        resource = Resource.put_time(resource, totalTime, to)
      end
    end
    handleNeighbours(planner, vertex, rest, resource, queue)
  end

#Build Plan from vertices
  defp plan(p, current, resource) do
    v = Resource.get_vertex(resource, current)
    p = Plan.prependStep(p, current, v.edgeTime, v.vertexTime)
    if v.previous == p.from do
      p
    else
      plan(p, v.previous, resource)
    end
  end
end
