defmodule Plan do
  defstruct from: nil, to: nil, steps: [], time: 0
# Steps format:
# Route from A -> B -> C
# Delays: throught A (start time): 0, A->B: 1, throught B: 2, B->C: 3, throught C: not important
# Steps: [ {B, 0, 1}, {C, 3, 6} ]

#Data to be sent to server:
# {A, B, C, B.vertexTime, B.edgeTime} = {A, B, C, 0, 1}
# {B, C, nil, C.vertexTime, nil} = {B, C, nil, 3, nil}

# B.vertexTime = time when entering segment A -> B
# = time after finishing junction A
# B.edgeTime = time when entering junction A -> B -> C
# = time after finishing segment A -> B
# C.vertexTime = time after finishing junction A -> B -> C
# = time when entering segment B -> C
# C.edgeTime = time when entering junction C -> not sent to server, as car
# "disappears" when it arrives to destination

# Last edge time is only for total travel time, is never sent to the server
# Time = total travel time
# Start time = steps[0].vertexTime
  def empty() do
    %Plan{}
  end

  def empty?(plan) do
    plan == %Plan{}
  end

  def new(from, to, time) do
    %Plan{ from: from, to: to, time: time }
  end

# Steps are build backwards
  def prependStep(plan, toVertex, edgeTime, vertexTime) do
    %Plan{ plan |
      steps: [{toVertex, vertexTime, edgeTime}] ++ plan.steps
    }
  end

  def calculateLength(%Global{} = global, plan) do
    Enum.reduce(plan.steps, {plan.from, 0}, fn ({to, _vt, _et}, {from, total}) ->
        {length, _type} = RoadMap.length_type(global.map, from, to)
        {to, total + length}
      end)
      |> elem(1)
  end

  def updateTimes(%Global{} = global, plan) do
    #First is handled differently, because first vertex time is starting time - and that one does not change
    [ {f_to, f_vt, _f_et} | f_rest] = plan.steps
    et = f_vt + Oracle.edge_time(global.oracle, plan.from, f_to, f_vt)
    first = {f_to, f_vt, et}

    {steps, {_to, total} } = Enum.map_reduce(f_rest, {f_to, et}, fn({to, _vt, _et}, {from, total}) ->
        vt = total + Oracle.vertex_time(global.oracle, from, to, total)
        et = vt + Oracle.edge_time(global.oracle, from, to, vt)
        { {to, vt, et}, {to, et} }
      end)
    %Plan{from: plan.from, to: plan.to, steps: [first] ++ steps, time: total - f_vt}
  end
end
