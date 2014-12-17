defmodule Counter do
  defstruct started: 0, finished: 0, all_started: false, callback: nil

  defmodule Waiter do
    defstruct finished: false, count: 0, waiting_pid: nil
    use GenServer

    def new() do
      {:ok, pid_w} = GenServer.start_link(__MODULE__, %Waiter{})
      pid_c = Counter.new(&finished(pid_w, &1))
      {pid_w, pid_c}
    end

    def spawn({_pid_w, pid_c}, callback) do
      Counter.spawn(pid_c, callback)
    end

    def all_started({_pid_w, pid_c}) do
      Counter.all_started(pid_c)
    end

    def wait_for({pid_w, _pid_c}) do
      GenServer.call(pid_w, :wait_for)
    end

    defp finished(pid_w, count) do
      GenServer.call(pid_w, {:finished, count})
    end

#GenServer
    def handle_call(:wait_for, _from, %Waiter{finished: true} = state) do
      {:reply, state.count, state}
    end

    def handle_call(:wait_for, from, %Waiter{finished: false} = state) do
      {:noreply, %Waiter{ state | waiting_pid: from} }
    end

    def handle_call({:finished, count}, _from, %Waiter{waiting_pid: nil} = state) do
      {:reply, :ok, %Waiter{ state | count: count, finished: true} }
    end

    def handle_call({:finished, count}, _from, %Waiter{waiting_pid: pid_w} = state) do
      GenServer.reply(pid_w, count)
      {:reply, :ok, %Waiter{ state | count: count, finished: true} }
    end
  end

  def new(callback) do
    {:ok, pid} = Agent.start_link(fn -> %Counter{ callback: callback } end)
    pid
  end

  def started(pid) do
    Agent.update(pid, fn(state) ->
        %{ state | started: state.started + 1 }
      end)
  end

  def all_started(pid) do
    Agent.update(pid, fn(state) ->
        newstate = %{ state | all_started: true }
        if newstate.all_started && newstate.started == newstate.finished do
          stop_fn(pid, newstate)
        end
        newstate
      end)
  end

  def finished(pid) do
    Agent.update(pid, fn(state) ->
        newstate = %{ state | finished: state.finished + 1 }
        if newstate.all_started && newstate.started == newstate.finished do
          stop_fn(pid, newstate)
        end
        newstate
      end)
  end

  def stop_fn(pid, state) do
    spawn fn ->
      :ok = Agent.stop(pid)
      state.callback.(state.started)
    end
  end

  def spawn(pid, callback)
    when is_function(callback) do
    started(pid)
    spawn fn ->
      callback.()
      finished(pid)
    end
  end

  def spawn(pid, callback, result_callback)
    when is_function(callback) and
        is_function(result_callback) do
    started(pid)
    spawn fn ->
      callback.()
      |> result_callback.()
      finished(pid)
    end
  end
end

