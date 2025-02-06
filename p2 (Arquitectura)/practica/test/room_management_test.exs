# test/kahoot_clone/room_manager_test.exs
defmodule KahootClone.RoomManagerTest do
  use ExUnit.Case
  alias KahootClone.RoomManager
  alias KahootClone.Game

  setup do
    # Preguntas de prueba
    questions = [
      %{
        question: "¿Cuál es la capital de España?",
        answers: ["Lisboa", "Madrid", "Barcelona", "Sevilla"],
        correct_answer: "Madrid"
      }
    ]

    Supervisor.terminate_child(KahootClone.AppSupervisor, RoomManager)
    Supervisor.restart_child(KahootClone.AppSupervisor, RoomManager)

    %{questions: questions}
  end

  @tag unit: true
  test "crear y obtener sala de juego", %{questions: questions} do
    # Crear sala
    {:ok, code, game_pid} = RoomManager.create_room("Creador", questions)

    # Verificar que se puede obtener la sala
    {:ok, retrieved_pid} = RoomManager.join_room(code, "", self())
    assert is_pid(game_pid)
    assert game_pid == retrieved_pid
  end

  @tag unit: true
  test "intentar obtener sala inexistente" do
    result = RoomManager.join_room("codigoInexistente", "Nombre", self())

    assert result == {:error, :room_not_found}
  end

  @tag unit: true
  test "concurrencia al crear salas", %{questions: questions} do
    parent = self()

    # Crear salas concurrentemente
    tasks =
      Enum.map(1..10, fn _ ->
        Task.async(fn ->
          result = RoomManager.create_room("Creador", questions)
          send(parent, {:room_created, result})
          result
        end)
      end)

    # Recolectar resultados
    results = Enum.map(tasks, &Task.await/1)

    # Verificar que no haya códigos duplicados
    codes = Enum.map(results, fn {:ok, code, _pid} -> code end)
    assert length(Enum.uniq(codes)) == length(results)
  end

  @tag integration: true
  test "iniciar e interrumpir partida", %{questions: questions} do
    init_pool = RoomManager.get_pool()
    assert length(init_pool) == 5

    {:ok, code, game_pid} = RoomManager.create_room("creador", questions)

    pool = RoomManager.get_pool()
    # Comprobar que el código de sala se fue de la pool
    assert length(pool) == 4
    assert code in init_pool
    refute code in pool

    {:ok, _game_pid} = RoomManager.join_room(code, "Jugador1", self())
    {:ok, _game_pid} = RoomManager.join_room(code, "Jugador2", self())

    :ok = Game.start_game(game_pid)

    # Responder primera pregunta
    :ok = Game.answer_question(game_pid, "Jugador1", "París")
    :ok = Game.answer_question(game_pid, "Jugador2", "Madrid")

    # Terminar juego prematuramente
    GenServer.cast(game_pid, :end_game)
    # Esperar a que el mensaje del proceso llegue
    :timer.sleep(2000)

    # Comprobar que el código ha vuelto a la pool
    end_pool = RoomManager.get_pool()
    assert length(end_pool) == 5
    assert code in end_pool
  end

  @tag integration: true
  test "crear múltiples salas", %{questions: questions} do
    # Obtener pool inicial
    pool = RoomManager.get_pool()
    assert length(pool) == 5

    # Crear varias salas
    results =
      Enum.map(1..5, fn _ ->
        RoomManager.create_room("Creador", questions)
      end)

    # Verificar que no quedan salas en el RoomManager
    newPool = RoomManager.get_pool()
    assert length(newPool) == 0

    # Verificar que se crearon salas únicas
    unique_codes =
      results
      |> Enum.map(fn {:ok, code, _pid} -> code end)
      |> Enum.uniq()

    assert length(unique_codes) == length(results)
  end
end
