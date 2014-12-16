defmodule Plan do
  defstruct from: nil, to: nil, steps: [], time: 0
# Steps format:
# Route from A -> B -> C
# Delays: throught A (start time): 0, A->B: 1, throught B: 2, B->C: 3, throught C: not important
# Steps: [ {B, 0, 1}, {C, 3, 6} ]

#Data to be sent to server:
# {A, B, C, B.vertexTime, B.edgeTime} = {A, B, C, 0, 1}
# {B, C, nil, 3, nil}

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
end

