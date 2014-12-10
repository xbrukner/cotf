defmodule Car do
  defstruct from: nil, start_time: 0, to: nil, plan: nil, global: nil
  use GenServer

  def new(from, start_time, to, global) do
    {:ok, pid} = GenServer.start_link(__MODULE__, {from, start_time, to, global})
    pid
  end

  def get_info(pid) do
    GenServer.call(pid, :info)
  end

  def calculate_plan(pid) do
    GenServer.call(pid, :calculate_plan)
  end

  def send_plan(pid) do
    GenServer.call(pid, :send_plan)
  end

# GenServer
  def init({from, start_time, to, global}) do
    {:ok, %Car{from: from, start_time: start_time, to: to, global: global}}
  end

  def handle_call(:info, _from, state) do
    {:reply, state, state}
  end

  def handle_call(:calculate_plan, _from, state) do
    #TODO - start_time
    plan = Planner.route(state.global.planner, state.from, state.to)
    state = %Car{state | plan: plan}
    {:reply, :ok, state}
  end

  def handle_call(:send_plan, _from, state) do
    a = state.global.aggregator
    p = state.plan
    
    send_plan(a, 0, p.from, p.steps)
    
    {:reply, :ok, state}
  end

#termination
  defp send_plan(_a, _time, _from, []) do
  end

  defp send_plan(a, time, from, [next | rest]) do
    to = if Enum.empty?(rest) do
      nil
    else
      Enum.fetch!(rest, 0)
      |> elem(0)
    end

#TODO - this is not correct ATM since the plan format is wrong
    t1 = time + elem(next, 1)
    t2 = t1 + elem(next, 2)
    Aggregator.insert(a, from, elem(next, 0), to, t1, t2)
    
    send_plan(a, t2, elem(next, 0), rest)
  end
end

