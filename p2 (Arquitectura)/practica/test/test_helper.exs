ExUnit.start()

{:ok, _pid} = KahootClone.AppSupervisor.start_link()
