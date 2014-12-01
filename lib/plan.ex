defmodule Plan do
  defstruct from: nil, to: nil, steps: [], time: 0
# Steps format:
# Route from A -> B -> C
# Delays: throught A: 0, A->B: 1, throught B: 2, B->C: 3, throught C: not important
# Steps: [ {B, 0, 1}, {C, 2, 3} ]

#Data to be sent to server:
# sum = 0
# {A, B, C, sum + B.vertexTime, sum + B.vertexTime + B.edgeTime} = {A, B, C, 0, 1}
# sum = sum + B.vertexTime + B.edgeTime
# {B, C, nil, 3, nil}

# Last edge time is only for total travel time, is never sent to the server

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

