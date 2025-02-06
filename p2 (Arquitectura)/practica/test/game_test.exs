# test/kahoot_clone/game_test.exs
defmodule KahootClone.GameTest do
  use ExUnit.Case
  alias KahootClone.Game

  setup do
    # Generar un código de juego único
    code = :crypto.strong_rand_bytes(2) |> Base.encode16() |> String.downcase()

    # Crear un conjunto de preguntas de prueba
    questions = [
      %{
        question: "¿Cuál es la capital de Francia?",
        answers: ["Londres", "Berlín", "París", "Madrid"],
        correct_answer: "París"
      },
      %{
        question: "¿Cuántos planetas hay en el sistema solar?",
        answers: ["7", "8", "9", "10"],
        correct_answer: "8"
      }
    ]

    # Iniciar el juego
    {:ok, pid} = Game.start_link(code)
    Game.init_game(pid, "CreadorTest", questions)

    %{game_pid: pid, code: code, questions: questions}
  end

  @tag unit: true
  test "inicialización de estado del juego", %{game_pid: pid} do
    state = Game.get_game_state(pid)
    assert state.state == :waiting
    assert state.players == %{}
    assert state.current_question == 0
  end

  @tag unit: true
  test "agregar múltiples jugadores con nombres diferentes", %{game_pid: pid} do
    players = ["Jugador1", "Jugador2", "Jugador3"]

    results =
      Enum.map(players, fn player ->
        Game.join_game(pid, player, self())
      end)

    assert Enum.all?(results, fn result -> result == {:ok, pid} end)

    state = Game.get_game_state(pid)
    assert map_size(state.players) == 3
    assert Enum.all?(players, fn player -> Map.has_key?(state.players, player) end)
  end

  @tag unit: true
  test "manejo de caracteres especiales en nombres de jugadores", %{game_pid: pid} do
    special_names = [
      "Jugador_Con_Guion",
      "Jugador Con Espacios",
      "JugadorÑ",
      "Jugador123"
    ]

    results =
      Enum.map(special_names, fn player ->
        Game.join_game(pid, player, self())
      end)

    assert Enum.all?(results, fn result -> result == {:ok, pid} end)
  end

  @tag unit: true
  test "manejo de jugador con nombre duplicado", %{game_pid: pid} do
    # Primer intento de unión
    {:ok, pid} = Game.join_game(pid, "Jugador1", self())

    # Intento de unión con mismo nombre
    result = Game.join_game(pid, "Jugador1", self())

    assert result == {:error, :name_taken}
  end

  @tag unit: true
  test "máximo de jugadores", %{game_pid: pid} do
    # Intentar unir 6 jugadores (más de lo razonable)
    results =
      Enum.map(1..6, fn i ->
        Game.join_game(pid, "Jugador#{i}", self())
      end)

    # El primer jugador debería unirse sin problemas
    assert Enum.at(results, 0) == {:ok, pid}

    # Dado que no hay un límite de jugadores definido, no debería dar error y se unen sin problema
    assert Enum.all?(Enum.drop(results, 1), fn result ->
             result == {:ok, pid}
           end)
  end

  @tag integration: true
  test "flujo completo de juego con puntuaciones", %{game_pid: pid, questions: _questions} do
    # Unir jugadores
    {:ok, pid} = Game.join_game(pid, "Jugador1", self())
    {:ok, pid} = Game.join_game(pid, "Jugador2", self())

    # Iniciar juego
    :ok = Game.start_game(pid)

    # Simular respuestas de jugadores
    :ok = Game.answer_question(pid, "Jugador1", "París")
    :ok = Game.answer_question(pid, "Jugador2", "Madrid")

    # Avanzar a la siguiente pregunta
    send(pid, :next_question)

    # Simular respuestas de la segunda pregunta
    :ok = Game.answer_question(pid, "Jugador1", "8")
    :ok = Game.answer_question(pid, "Jugador2", "8")

    # Obtener estado final del juego
    state = Game.get_game_state(pid)

    assert state.state == :finished
    # Respuestas correctas
    assert state.scores["Jugador1"] == 200
    # Una respuesta correcta
    assert state.scores["Jugador2"] == 100
  end

  @tag integration: true
  test "timeout de pregunta si no todos responden", %{game_pid: pid, questions: _questions} do
    # Unir jugadores
    {:ok, pid} = Game.join_game(pid, "Jugador1", self())
    {:ok, pid} = Game.join_game(pid, "Jugador2", self())

    # Iniciar juego
    :ok = Game.start_game(pid)

    # Solo un jugador responde
    :ok = Game.answer_question(pid, "Jugador1", "París")

    # Simular paso del tiempo
    send(pid, :next_question)

    # Obtener estado
    state = Game.get_game_state(pid)

    # Verificar que se avanza a la siguiente pregunta aunque no todos hayan respondido
    assert state.current_question == 1
  end

  @tag integration: true
  test "juego con múltiples preguntas", %{game_pid: pid, questions: _questions} do
    # Unir jugadores
    {:ok, pid} = Game.join_game(pid, "Jugador1", self())
    {:ok, pid} = Game.join_game(pid, "Jugador2", self())

    # Iniciar juego
    :ok = Game.start_game(pid)

    # Responder primera pregunta
    :ok = Game.answer_question(pid, "Jugador1", "París")
    :ok = Game.answer_question(pid, "Jugador2", "Madrid")

    # Avanzar a siguiente pregunta
    send(pid, :next_question)

    # Responder segunda pregunta
    :ok = Game.answer_question(pid, "Jugador1", "8")
    :ok = Game.answer_question(pid, "Jugador2", "8")

    # Avanzar a siguiente pregunta (que debería terminar el juego)
    send(pid, :next_question)

    # Obtener estado final
    state = Game.get_game_state(pid)

    assert state.state == :finished
    assert map_size(state.scores) == 2
  end

  @tag integration: true
  test "manejo de juego sin preguntas", %{game_pid: pid} do
    # Unir jugadores
    {:ok, pid} = Game.join_game(pid, "Jugador1", self())

    # Iniciar juego sin preguntas
    Game.init_game(pid, "CreadorTest", [])
    :ok = Game.start_game(pid)

    # Obtener estado final
    state = Game.get_game_state(pid)

    assert state.state == :finished
  end

  @tag integration: true
  test "límite de tiempo para responder", %{game_pid: pid, questions: _questions} do
    # Unir jugadores
    {:ok, pid} = Game.join_game(pid, "Jugador1", self())
    {:ok, pid} = Game.join_game(pid, "Jugador2", self())

    # Iniciar juego
    :ok = Game.start_game(pid)

    # No responder dentro del tiempo límite
    # Esperar más del timeout definido (20 segundos)
    :timer.sleep(25_000)

    # Obtener estado
    state = Game.get_game_state(pid)

    # Verificar que se ha avanzado a la siguiente pregunta
    assert state.current_question == 1
    # Nadie respondió
    assert state.answers == 0
  end

  @tag integration: true
  test "puntuación con diferentes respuestas", %{game_pid: pid, questions: _questions} do
    # Unir jugadores
    {:ok, pid} = Game.join_game(pid, "Jugador1", self())
    {:ok, pid} = Game.join_game(pid, "Jugador2", self())

    # Iniciar juego
    :ok = Game.start_game(pid)

    # Respuestas diferentes
    # Correcta
    :ok = Game.answer_question(pid, "Jugador1", "París")
    # Incorrecta
    :ok = Game.answer_question(pid, "Jugador2", "Madrid")

    # Avanzar a siguiente pregunta
    send(pid, :next_question)

    # Segunda pregunta
    # Correcta
    :ok = Game.answer_question(pid, "Jugador1", "8")
    # Correcta
    :ok = Game.answer_question(pid, "Jugador2", "8")

    # Finalizar juego
    send(pid, :next_question)

    # Obtener estado final
    state = Game.get_game_state(pid)

    # Verificar puntuaciones
    # Ambas respuestas correctas
    assert state.scores["Jugador1"] == 200
    # Una respuesta correcta
    assert state.scores["Jugador2"] == 100
  end

  @tag integration: true
  test "reinicio de juego después de finalizar", %{game_pid: pid, questions: _questions} do
    # Unir jugadores
    {:ok, pid} = Game.join_game(pid, "Jugador1", self())
    {:ok, pid} = Game.join_game(pid, "Jugador2", self())

    # Iniciar juego
    :ok = Game.start_game(pid)

    # Completar el juego
    :ok = Game.answer_question(pid, "Jugador1", "París")
    :ok = Game.answer_question(pid, "Jugador2", "Madrid")
    send(pid, :next_question)

    :ok = Game.answer_question(pid, "Jugador1", "8")
    :ok = Game.answer_question(pid, "Jugador2", "8")
    send(pid, :next_question)

    # Verificar estado final
    state = Game.get_game_state(pid)
    assert state.state == :finished

    # Intentar reiniciar el juego
    result = Game.start_game(pid)

    # La implementación específica determinará el comportamiento esperado
    # Podría ser un error o un reinicio limpio
    assert result in [:ok, {:error, :game_already_finished}]
  end

  @tag integration: true
  test "rendimiento con muchas preguntas", %{game_pid: pid} do
    many_questions =
      Enum.map(1..20, fn i ->
        %{
          question: "Pregunta #{i}",
          answers: ["A", "B", "C", "D"],
          correct_answer: "A"
        }
      end)

    :ok = Game.init_game(pid, "CreadorTest", many_questions)
    {:ok, pid} = Game.join_game(pid, "Jugador1", self())
    :ok = Game.start_game(pid)

    # Simular respuestas a todas las preguntas
    Enum.each(many_questions, fn question ->
      :ok = Game.answer_question(pid, "Jugador1", question.correct_answer)
      send(pid, :next_question)
    end)

    state = Game.get_game_state(pid)
    assert state.state == :finished
  end
end
