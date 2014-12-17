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

  def result(pid) do
    GenServer.call(pid, :result)
  end

# GenServer
  def init({from, start_time, to, global}) do
    {:ok, %Car{from: from, start_time: start_time, to: to, global: global, plan: Plan.empty}}
  end

  def handle_call(:info, _from, state) do
    {:reply, state, state}
  end

  def handle_call(:result, _from, state) do
    {:reply, "#{state.from},#{state.to},#{state.start_time}," <>
      "#{state.orig_plan.time}," <> to_string(Plan.calculateLength(state.global, state.orig_plan)) <>
      ",#{state.plan.time}," <> to_string(Plan.calculateLength(state.global, state.plan)),
      state}
  end

  def handle_call(:calculate_plan, _from, state) do
    if Plan.empty?(state.last_plan) do #Second plan - same route, update times
      orig_plan = state.plan
      state = %Car{state | orig_plan: orig_plan }
    end
    state = %Car{state | last_plan: state.plan} #Copy last plan
    
    plan = Planner.route(state.global.planner, state.from, state.to, state.start_time)
    state = %Car{state | plan: plan}
    {:reply, :ok, state}
  end

  def handle_call(:send_plan, _from, state) do
    a = state.global.aggregator
    p = state.plan

    l_p = state.last_plan
    
    send_plan(a, p.from, p.steps, l_p.from, l_p.steps )
    
    {:reply, :ok, state}
  end

#termination
  defp send_plan(_a, _from, [], _l_from, []) do
  end

#Only old plan
  defp send_plan(a, _from, [], l_from, [l_next | l_rest]) do
    {newfrom, info} = extract_send_info(l_from, l_next, l_rest)
    Aggregator.delete(a, info)
    
    send_plan(a, nil, [], newfrom, l_rest)
  end

#Only new plan
  defp send_plan(a, from, [next | rest], _l_from, []) do
    {newfrom, info} = extract_send_info(from, next, rest)
    Aggregator.insert(a, info)
    
    send_plan(a, newfrom, rest, nil, [])
  end

#Both plans
  defp send_plan(a, from, [next | rest], l_from, [l_next | l_rest]) do
    {newfrom, info} = extract_send_info(from, next, rest)
    {l_newfrom, l_info} = extract_send_info(l_from, l_next, l_rest)
    Aggregator.update(a, l_info, info)
    
    send_plan(a, newfrom, rest, l_newfrom, l_rest)
  end

  defp extract_send_info(from, next, rest) do
    to = if Enum.empty?(rest) do
      nil
    else
      Enum.fetch!(rest, 0)
      |> elem(0)
    end

    {via, vertexTime, edgeTime} = next
    {via, {from, via, to, vertexTime, edgeTime} }
  end
end

