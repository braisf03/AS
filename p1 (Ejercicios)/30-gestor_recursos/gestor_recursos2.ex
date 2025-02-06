defmodule Gestor do
  use GenServer

  @name {:global, __MODULE__}

  # API del cliente
  def start(recursos) do
    GenServer.start_link(__MODULE__, recursos, name: @name)
    |> case do
      {:ok, pid} ->
        :global.sync()
        {:ok, pid}
      error -> error
    end
  end

  def alloc do
    GenServer.call(@name, {:alloc, self()})
  end

  def release(recurso) do
    GenServer.call(@name, {:release, self(), recurso})
  end

  def avail do
    GenServer.call(@name, :avail)
  end

  # Callbacks del servidor
  @impl true
  def init(recursos) do
    {:ok, %{disponibles: recursos, asignados: %{}}}
  end

  @impl true
  def handle_call({:alloc, from}, _from, state) do
    case state.disponibles do
      [recurso | resto] ->
        new_state = %{
          state |
          disponibles: resto,
          asignados: Map.put(state.asignados, recurso, from)
        }
        {:reply, {:ok, recurso}, new_state}
      [] ->
        {:reply, {:error, :sin_recursos}, state}
    end
  end

  @impl true
  def handle_call({:release, from, recurso}, _from, state) do
    case Map.get(state.asignados, recurso) do
      ^from ->
        new_state = %{
          state |
          disponibles: [recurso | state.disponibles],
          asignados: Map.delete(state.asignados, recurso)
        }
        {:reply, :ok, new_state}
      _ ->
        {:reply, {:error, :recurso_no_reservado}, state}
    end
  end

  @impl true
  def handle_call(:avail, _from, state) do
    {:reply, length(state.disponibles), state}
  end
end
