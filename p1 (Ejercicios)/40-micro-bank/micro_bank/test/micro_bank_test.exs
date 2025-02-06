defmodule MicroBankTest do
  use ExUnit.Case

  setup do
    # Inicia el supervisor manualmente
    MicroBank.Supervisor.start_link(:ok)
    :ok
  end

  test "deposits money" do
    MicroBank.deposit("Alice", 100)
    assert MicroBank.ask("Alice") == 100
  end

  test "withdraws money" do
    MicroBank.deposit("Bob", 100)
    MicroBank.withdraw("Bob", 50)
    assert MicroBank.ask("Bob") == 50
  end

  test "does not withdraw more than balance" do
    MicroBank.deposit("Charlie", 100)
    MicroBank.withdraw("Charlie", 150)
    assert MicroBank.ask("Charlie") == 100
  end

  test "asks for balance" do
    MicroBank.deposit("Dena", 200)
    assert MicroBank.ask("Dena") == 200
  end

  test "supervisor restarts server with a new pid after crash" do
    # Obtiene el PID inicial del proceso MicroBank
    initial_pid = Process.whereis(MicroBank)
    assert is_pid(initial_pid)

    # Simula un fallo en el proceso
    Process.exit(initial_pid, :kill)

    # Espera el reinicio del supervisor
    :timer.sleep(100)

    # Obtiene el nuevo PID
    new_pid = Process.whereis(MicroBank)
    assert is_pid(new_pid)

    # Verifica que el nuevo PID sea diferente
    assert initial_pid != new_pid
  end
end
