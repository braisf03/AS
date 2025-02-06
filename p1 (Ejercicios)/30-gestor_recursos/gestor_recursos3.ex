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
    {:ok, %{disponibles: recursos, asignados: %{}, monitores: %{}}}
  end

  @impl true
  def handle_call({:alloc, from}, _from, state) do
    case state.disponibles do
      [recurso | resto] ->
        monitor_ref = Process.monitor(from)
        new_state = %{
          state |
          disponibles: resto,
          asignados: Map.put(state.asignados, recurso, from),
          monitores: Map.put(state.monitores, monitor_ref, recurso)
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
        new_state = liberar_recurso(state, recurso)
        {:reply, :ok, new_state}
      _ ->
        {:reply, {:error, :recurso_no_reservado}, state}
    end
  end

  @impl true
  def handle_call(:avail, _from, state) do
    {:reply, length(state.disponibles), state}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    case Map.get(state.monitores, ref) do
      nil ->
        {:noreply, state}
      recurso ->
        new_state = liberar_recurso(state, recurso)
        {:noreply, new_state}
    end
  end

  @impl true
  def handle_info({:nodedown, node}, state) do
    new_state = Enum.reduce(state.asignados, state, fn {recurso, pid}, acc ->
      if node(pid) == node do
        liberar_recurso(acc, recurso)
      else
        acc
      end
    end)
    {:noreply, new_state}
  end

  defp liberar_recurso(state, recurso) do
    {pid, new_asignados} = Map.pop(state.asignados, recurso)
    {ref, new_monitores} = Enum.find(state.monitores, fn {_, r} -> r == recurso end)
                           |> case do
                             {ref, _} -> {ref, Map.delete(state.monitores, ref)}
                             nil -> {nil, state.monitores}
                           end
    if ref, do: Process.demonitor(ref)
    %{
      state |
      disponibles: [recurso | state.disponibles],
      asignados: new_asignados,
      monitores: new_monitores
    }
  end
end
