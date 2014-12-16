defmodule Counter do
  defstruct started: 0, finished: 0, all_started: false, callback: nil

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

