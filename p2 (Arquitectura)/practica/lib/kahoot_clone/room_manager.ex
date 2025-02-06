# lib/kahoot_clone/room_manager.ex

defmodule KahootClone.RoomManager do
  @moduledoc """
    Módulo líder en la arquitectura líder-trabajador encargado de gestionar las salas (rooms) de juego.

    ## Funcionalidad:
    - Administra un mapa de todas las partidas activas, asignando un identificador único (`code`) a cada una.
    - Permite la creación y consulta de partidas.
    - Gestiona la relación entre códigos de sala y los procesos supervisados que representan cada partida.

    ## Estructura:
    - Utiliza un `GenServer` para mantener el estado de las salas activas.
    - Coordina con `KahootClone.RootSupervisor` para crear procesos supervisados dinámicamente.
    - Utiliza un registro global (`:global`) para asegurar que las operaciones sean únicas en la red.

    ## Estado:
    - El estado interno del servidor es un conjunto de códigos que indica las salas libres.
    - Para buscar una sala se apoya de un registro (Registry) en el cual las salas se registran al crearse poniendo su codigo como clave.
  """

  use GenServer

  # Número inicial de salas en el pool
  @pool_size 5
  # Número mínimo de salas libres
  @min_free 3
  # Número máximo de salas libres
  @max_free 5

  @doc """
    Inicia el `GenServer` del `RoomManager` como un proceso global.

    ## Parámetros:
      - `_opts`: Parámetro opcional no utilizado.

    ## Retorno:
      - `{:ok, pid}`: Si el `GenServer` se inicia correctamente.
      - `{:error, reason}`: Si ocurre algún problema durante la inicialización.
  """

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: {:global, __MODULE__})
  end

  @doc """
    Inicializa el estado del `RoomManager`.

    ## Retorno:
      - `{:ok, state}`: Donde el estado inicial es un mapa vacío de juegos libres.
  """

  def init(_) do
    {:ok, %{pool: MapSet.new()}, {:continue, :init_pool}}
  end

  @doc false

  def handle_continue(:init_pool, state) do
    pool =
      Enum.reduce(1..@pool_size, state.pool, fn _, acc ->
        code = create_new_room()
        MapSet.put(acc, code)
      end)

    schedule_pool_check()
    {:noreply, %{state | pool: pool}}
  end

  @doc """
    Crea una nueva sala (room) o asinga una de las salas existentes.

    ## Parámetros:
      - `creator`: Nombre de la persona a la que se le asigna la sala.
      - `questions`: Preguntas y respuestas correctas del cuestionario.

    ## Retorno:
      - `{:ok, code, game_pid}`: Si la sala se crea correctamente.
      - `{:error, reason}`: Si ocurre un error durante la creación.
  """

  def create_room(creator, questions) do
    GenServer.call({:global, __MODULE__}, {:create_room, creator, questions})
  end

  @doc """
    Añade a una persona a una sala para poder jugar.

    ## Parámetros:
      - `code`: Código único que identifica la sala.
      - `player_name`: Nombre de la persona que entra en la sala.
      - `player_pid`: PID del jugador.

    ## Retorno:
      - `{:ok, pid}`: Si la sala existe.
      - `{:error, :game_not_found}`: Si la sala no está registrada.
  """

  def join_room(code, player_name, player_pid) do
    GenServer.call({:global, __MODULE__}, {:join_room, code, player_name, player_pid})
  end

  @doc """
    Función que retorna la pool de salas libres (principalmente usada para testing).

    ## Retorno:
      - `pool`: Lista que contiene todas las salas que había en la pool al momento de la petición
  """

  def get_pool do
    GenServer.call({:global, __MODULE__}, {:get_pool})
  end

  @doc false

  def handle_call({:create_room, creator, questions}, _from, state) do
    # code = generate_unique_code(state.games)
    case assign_or_create_room(state) do
      {code, game_pid, new_state} ->
        :ok = KahootClone.Game.init_game(game_pid, creator, questions)
        {:reply, {:ok, code, game_pid}, new_state}

      {:error, :not_found} ->
        {:reply, {:error, :game_creation_failed}, state}
    end
  end

  @doc false

  def handle_call({:join_room, code, player_name, player_pid}, _from, state) do
    case get_game_pid(code) do
      {:ok, game_pid} ->
        result = KahootClone.Game.join_game(game_pid, player_name, player_pid)
        {:reply, result, state}

      {:error, :not_found} ->
        {:reply, {:error, :room_not_found}, state}
    end
  end

  @doc false

  def handle_call({:get_pool}, _from, state) do
    {:reply, MapSet.to_list(state.pool), state}
  end

  @doc false

  def handle_info(:check_pool_size, state) do
    new_state = adjust_pool_size(state)
    schedule_pool_check()
    {:noreply, new_state}
  end

  @doc false

  def handle_info({:game_ended, code}, state) do
    case get_game_pid(code) do
      {:ok, _} ->
        new_pool = MapSet.put(state.pool, code)
        {:noreply, %{state | pool: new_pool}}

      _ ->
        {:noreply, state}
    end
  end

  @doc false

  defp generate_unique_code do
    code = :crypto.strong_rand_bytes(2) |> Base.encode16() |> String.downcase()

    case Registry.lookup(KahootClone.GameRegistry, {KahootClone.Game, code}) do
      [] -> code
      _ -> generate_unique_code()
    end
  end

  @doc false

  defp get_game_pid(game_code) do
    case Registry.lookup(KahootClone.GameRegistry, {KahootClone.Game, game_code}) do
      [{pid, _}] -> {:ok, pid}
      [] -> {:error, :not_found}
    end
  end

  @doc false

  defp assign_or_create_room(state) do
    case Enum.at(state.pool, 0) do
      nil ->
        code = create_new_room()

        case Registry.lookup(KahootClone.GameRegistry, {KahootClone.Game, code}) do
          [{game_pid, _}] -> {code, game_pid, state}
          [] -> {:error, :not_found}
        end

      code ->
        case get_game_pid(code) do
          {:ok, game_pid} ->
            {code, game_pid, %{state | pool: MapSet.delete(state.pool, code)}}

          {:error, :not_found} ->
            {:error, :not_found}
        end
    end
  end

  @doc false

  defp create_new_room do
    code = generate_unique_code()
    {:ok, _supervisor_pid} = KahootClone.RootSupervisor.start_child(code)
    code
  end

  @doc false

  defp adjust_pool_size(state) do
    pool_size = MapSet.size(state.pool)

    cond do
      pool_size < @min_free ->
        new_rooms = Enum.map(1..(@min_free - length(state.pool)), fn _ -> create_new_room() end)

        new_pool =
          Enum.reduce(new_rooms, state.pool, fn {code, _}, acc -> MapSet.put(acc, code) end)

        %{state | pool: new_pool}

      pool_size > @max_free ->
        {to_keep, to_remove} = Enum.split(MapSet.to_list(state.pool), @max_free)
        Enum.each(to_remove, &terminate_room/1)
        %{state | pool: MapSet.new(to_keep)}

      true ->
        state
    end
  end

  @doc false

  defp terminate_room(code) do
    case Registry.lookup(KahootClone.GameRegistry, {KahootClone.Game, code}) do
      [{game_pid, _}] ->
        node = node(game_pid)
        :rpc.call(node, Process, :exit, [game_pid, :normal])

        :rpc.call(node, Registry, :unregister, [
          KahootClone.GameRegistry,
          {KahootClone.Game, code}
        ])

        :rpc.call(node, Registry, :unregister, [
          KahootClone.GameRegistry,
          {KahootClone.GameSupervisor, code}
        ])

      [] ->
        :ok
    end
  end

  @doc false

  defp schedule_pool_check do
    Process.send_after(self(), :check_pool_size, :timer.minutes(5))
  end
end
