defmodule Car do
  defstruct from: nil, start_time: 0, to: nil, orig_plan: nil, last_plan: nil, plan: nil, global: nil
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
    {:ok, %Car{from: from, start_time: start_time, to: to, global: global, plan: Plan.empty}}
  end

  def handle_call(:info, _from, state) do
    {:reply, state, state}
  end

  def handle_call(:calculate_plan, _from, state) do
    if Plan.empty?(state.last_plan) do #Second plan - same route, update times
      orig_plan = Planner.update_route_time(state.global, state.plan)
      state = %Car{state | orig_plan: orig_plan }
    end
    state = %Car{state | last_plan: state.plan} #Copy last plan
    
    #TODO - start_time
    plan = Planner.route(state.global.planner, state.from, state.to)
    state = %Car{state | plan: plan}
    {:reply, :ok, state}
  end

  def handle_call(:send_plan, _from, state) do
    a = state.global.aggregator
    p = state.plan

    l_p = state.last_plan
    
    send_plan(a, 0, p.from, p.steps, 0, l_p.from, l_p.steps )
    
    {:reply, :ok, state}
  end

#termination
  defp send_plan(_a, _time, _from, [], _l_time, _l_from, []) do
  end

#Only old plan
  defp send_plan(a, _time, _from, [], l_time, l_from, [l_next | l_rest]) do
    {newtime, newfrom, info} = extract_send_info(l_time, l_from, l_next, l_rest)
    Aggregator.delete(a, info)
    
    send_plan(a, 0, nil, [], newtime, newfrom, l_rest)
  end

#Only new plan
  defp send_plan(a, time, from, [next | rest], _l_time, _l_from, []) do
    {newtime, newfrom, info} = extract_send_info(time, from, next, rest)
    Aggregator.insert(a, info)
    
    send_plan(a, newtime, newfrom, rest, 0, nil, [])
  end

#Both plans
  defp send_plan(a, time, from, [next | rest], l_time, l_from, [l_next | l_rest]) do
    {newtime, newfrom, info} = extract_send_info(time, from, next, rest)
    {l_newtime, l_newfrom, l_info} = extract_send_info(l_time, l_from, l_next, l_rest)
    Aggregator.update(a, l_info, info)
    
    send_plan(a, newtime, newfrom, rest, l_newtime, l_newfrom, l_rest)
  end

  defp extract_send_info(time, from, next, rest) do
    to = if Enum.empty?(rest) do
      nil
    else
      Enum.fetch!(rest, 0)
      |> elem(0)
    end

    #TODO - this is not correct ATM since the plan format is wrong
    t1 = time + elem(next, 1)
    t2 = t1 + elem(next, 2)
    {t2, elem(next, 0), {from, elem(next, 0), to, t1, t2} }
  end
end

