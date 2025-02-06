defmodule MicroBank do
  use GenServer

  # Cliente

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def stop do
    GenServer.stop(__MODULE__)
  end

  def deposit(who, amount) when amount > 0 do
    GenServer.cast(__MODULE__, {:deposit, who, amount})
  end

  def withdraw(who, amount) when amount > 0 do
    GenServer.cast(__MODULE__, {:withdraw, who, amount})
  end

  def ask(who) do
    GenServer.call(__MODULE__, {:ask, who})
  end

  # Nuevo método para reiniciar el estado
  def reset_state do
    GenServer.call(__MODULE__, :reset_state)
  end

  # Servidor

  def init(_) do
    {:ok, %{}}
  end

  def handle_cast({:deposit, who, amount}, state) do
    new_balance = Map.get(state, who, 0) + amount
    new_state = Map.put(state, who, new_balance)
    {:noreply, new_state}
  end

  def handle_cast({:withdraw, who, amount}, state) do
    current_balance = Map.get(state, who, 0)

    if current_balance >= amount do
      new_balance = current_balance - amount
      new_state = Map.put(state, who, new_balance)
      {:noreply, new_state}
    else
      {:noreply, state} # No se hace nada si no hay suficientes fondos
    end
  end

  def handle_call({:ask, who}, _from, state) do
    balance = Map.get(state, who, 0)
    {:reply, balance, state}
  end

  # Nuevo manejador para reiniciar el estado
  def handle_call(:reset_state, _from, _state) do
    {:reply, :ok, %{}}
  end
end
