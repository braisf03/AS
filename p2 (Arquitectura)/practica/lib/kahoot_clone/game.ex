# lib/kahoot_clone/game.ex

defmodule KahootClone.Game do
  @moduledoc """
    Este módulo representa una sala de juego en KahootClone. Maneja la lógica del juego, los jugadores, las preguntas,
    y el estado actual del juego. Implementa un `GenServer` para manejar concurrencia y estado compartido.
  """

  use GenServer

  @timeout 20_000

  @doc """
    Estructura que define el estado del juego.

    ## Campos:
      - `:code` (string): Código único de la sala.
      - `:creator` (string): Creador de la sala.
      - `:players` (map): Lista de jugadores registrados en el juego.
      - `:questions` (list): Lista de preguntas para el juego.
      - `:current_question` (integer): Índice de la pregunta actual.
      - `:answers` (integer): Número de respuestas enviadas para la pregunta actual.
      - `:scores` (map): Puntuación acumulada de cada jugador.
      - `:state` (atom): Estado del juego (`:waiting`, `:playing`, o `:finished`).
      - `:timer_ref` (reference): Referencia al temporizador activo.
  """

  defstruct [
    :code,
    :creator,
    :players,
    :questions,
    :current_question,
    :answers,
    :scores,
    :state,
    :timer_ref
  ]

  @doc """
    Inicia un nuevo proceso `GenServer` para manejar el estado del juego.

    ## Parámetros:
      - `code` (string): Código único de la sala.

    ## Retorno:
      - `{:ok, pid}` si el proceso se inicia correctamente.
      - `{:error, reason}` en caso de error.
  """

  def start_link(code) do
    GenServer.start_link(__MODULE__, code, name: via_tuple(code))
  end

  @doc """
    Inicializa el estado del juego con un código único.

    ## Parámetros:
      - `code` (string): Código único de la sala.

    ## Retorno:
      - `{:ok, initial_state}`: El estado inicial del juego.
  """

  def init(code) do
    if String.to_atom(code) in :ets.all() do
      {:ok, load_state(code)}
    else
      :ets.new(String.to_atom(code), [:set, :protected, :named_table])

      {:ok,
       %__MODULE__{
         code: code,
         players: %{},
         questions: [],
         current_question: 0,
         answers: 0,
         scores: %{},
         state: :waiting,
         timer_ref: nil
       }}
    end
  end

  @doc false

  defp via_tuple(code) do
    {:via, Registry, {KahootClone.GameRegistry, {__MODULE__, code}}}
  end

  @doc """
    Inicializa una sala con un creador y una lista de preguntas.

    ## Parámetros:
      - `pid` (pid): PID del proceso de la sala.
      - `creator` (string): Nombre del creador de la sala.
      - `questions` (list): Lista de preguntas para el juego.

    ## Retorno:
      - `:ok` si la sala se inicializa correctamente.
  """

  def init_game(pid, creator, questions) do
    GenServer.call(pid, {:init_game, creator, questions})
  end

  @doc """
    Permite a un jugador unirse a una sala.

    ## Parámetros:
      - `pid` (pid): PID del proceso de la sala.
      - `player_name` (string): Nombre del jugador.
      - `player_pid` (pid): PID del proceso del jugador.

    ## Retorno:
      - `:ok` si el jugador se une correctamente.
      - `{:error, :name_taken}` si el nombre ya está en uso.
  """

  def join_game(pid, player_name, player_pid) do
    GenServer.call(pid, {:join_game, player_name, player_pid})
  end

  @doc """
    Comienza el juego, estableciendo el estado como `:playing`.

    ## Parámetros:
      - `pid` (pid): PID del proceso de la sala.

    ## Retorno:
      - `:ok` si el juego comienza correctamente.
  """

  def start_game(pid) do
    GenServer.call(pid, :start_game)
  end

  @doc """
    Envía una respuesta para la pregunta actual.

    ## Parámetros:
      - `pid` (pid): PID del proceso de la sala.
      - `player_name` (string): Nombre del jugador.
      - `answer` (any): Respuesta enviada por el jugador.

    ## Retorno:
      - `:ok` si la respuesta se procesa correctamente.
  """

  def answer_question(pid, player_name, answer) do
    GenServer.call(pid, {:answer_question, player_name, answer})
  end

  @doc """
    Obtiene el estado actual del juego.

    ## Parámetros:
      - `pid` (pid): PID del proceso de la sala.

    ## Retorno:
      - `state`: Estado actual del juego.
  """

  def get_game_state(pid) do
    GenServer.call(pid, :get_game_state)
  end

  @doc """
    Termina el juego, devolviendolo a la pool de salas libres.

    ## Parámetros:
      - `pid` (pid): PID del proceso de la sala.

  """

  def end_game(pid) do
    GenServer.cast(pid, :end_game)
  end

  @doc false

  def handle_call({:create_game, creator, questions}, _from, state) do
    new_state = %{state | creator: creator, questions: questions}
    save_state(new_state)
    {:reply, :ok, new_state}
  end

  @doc false

  def handle_call({:init_game, creator, questions}, _from, state) do
    new_state = %{state | creator: creator, questions: questions}
    save_state(new_state)
    {:reply, :ok, new_state}
  end

  @doc false

  def handle_call({:join_game, player_name, pid}, _from, state) do
    if Map.has_key?(state.players, player_name) do
      {:reply, {:error, :name_taken}, state}
    else
      new_players = Map.put(state.players, player_name, %{score: 0, pid: pid})
      new_state = %{state | players: new_players}
      save_state(new_state)
      {:reply, {:ok, self()}, new_state}
    end
  end

  @doc false

  def handle_call(:start_game, _from, state) do
    new_state = %{state | state: :playing, current_question: -1}
    send(self(), :next_question)
    save_state(new_state)
    {:reply, :ok, new_state}
  end

  @doc false

  def handle_call({:answer_question, player_name, answer}, _from, state) do
    current_question = Enum.at(state.questions, state.current_question)
    is_correct = answer == current_question.correct_answer
    points = if is_correct, do: calculate_points(state), else: 0

    new_scores = Map.update(state.scores, player_name, points, &(&1 + points))
    new_answers = state.answers + 1

    new_state = %{state | scores: new_scores, answers: new_answers}

    if all_players_answered?(new_state) do
      cancel_timer_safely(state.timer_ref)
      send(self(), :next_question)
    end

    save_state(new_state)
    {:reply, :ok, new_state}
  end

  @doc false

  def handle_call(:get_game_state, _from, state) do
    {:reply, state, state}
  end

  @doc false

  def handle_info(:next_question, state) do
    new_state = advance_question(state)

    if new_state.state == :finished do
      broadcast_to_players(new_state, {:game_finished, new_state.scores})
      {:noreply, %{new_state | timer_ref: nil}}
    else
      current_question = Enum.at(new_state.questions, new_state.current_question)
      broadcast_to_players(new_state, {:new_question, current_question})
      timer_ref = Process.send_after(self(), :next_question, @timeout)
      save_state(new_state)
      {:noreply, %{new_state | timer_ref: timer_ref}}
    end
  end

  @doc false
  def handle_cast(:end_game, state) do
    :ets.insert(String.to_atom(state.code), {:state, initial_state(state.code)})
    leader_pid = :global.whereis_name(KahootClone.RoomManager)
    send(leader_pid, {:game_ended, state.code})
    # Limpiar estado para devolverlo a la pool de trabajadores
    {:noreply, initial_state(state.code)}
  end

  @doc false

  def handle_cast(:terminate_room, state) do
    :ets.delete(String.to_atom(state.code))
    {:stop, :normal, state}
  end

  @doc false

  defp calculate_points(_state) do
    100
  end

  @doc false

  defp all_players_answered?(state) do
    state.answers == Enum.count(state.players)
  end

  @doc false

  defp advance_question(state) do
    if state.current_question + 1 < Enum.count(state.questions) do
      %{state | current_question: state.current_question + 1, answers: 0}
    else
      %{state | state: :finished}
    end
  end

  @doc false

  defp broadcast_to_players(state, message) do
    Enum.each(state.players, fn {_player_name, player_data} ->
      if is_pid(player_data.pid) do
        send(player_data.pid, message)
      end
    end)
  end

  @doc false

  defp cancel_timer_safely(timer_ref) do
    if is_reference(timer_ref) do
      Process.cancel_timer(timer_ref)
    end
  end

  @doc false

  defp save_state(state) do
    :ets.insert(String.to_atom(state.code), {:state, state})
  end

  @doc false

  defp load_state(code) do
    case :ets.lookup(String.to_atom(code), :state) do
      [{:state, state}] ->
        state

      [] ->
        initial_state(code)
    end
  end

  @doc false

  defp initial_state(code) do
    %__MODULE__{
      code: code,
      players: %{},
      questions: [],
      current_question: 0,
      answers: 0,
      scores: %{},
      state: :waiting,
      timer_ref: nil
    }
  end
end
