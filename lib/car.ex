defmodule Car do
  defstruct from: nil, start_time: 0, to: nil, plan: nil, planner: nil
  use GenServer

  def new(from, start_time, to, planner) do
    {:ok, pid} = GenServer.start_link(__MODULE__, {from, start_time, to, planner})
    pid
  end

  def get_info(pid) do
    GenServer.call(pid, :info)
  end

  def calculate_plan(pid) do
    GenServer.call(pid, :calculate_plan)
  end


  def init({from, start_time, to, planner}) do
    {:ok, %Car{from: from, start_time: start_time, to: to, planner: planner}}
  end

  def handle_call(:info, _from, state) do
    {:reply, state, state}
  end

  def handle_call(:calculate_plan, _from, state) do
    #TODO - start_time
    plan = Planner.route(state.planner, state.from, state.to)
    state = %Car{state | plan: plan}
    {:reply, :ok, state}
  end
end

