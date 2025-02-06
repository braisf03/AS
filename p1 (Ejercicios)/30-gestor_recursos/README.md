# Gestor de recursos

En este ejercicio comenzaremos por implementar un sencillo proceso que
gestione una lista de recursos.

A continuación pasaremos a realizar una versión distribuida del mismo,
para terminar en una tercera iteración tolerante a fallos.



## Descripción del gestor

En este ejercicio definiremos un servidor que actúe como un gestor de recursos,
que ofrezca los siguientes servicios:

  - `{:alloc, from}`, que devuelve a `from` el par `{:ok, recurso}`,
    si `recurso` es un recurso que se encuentra disponible, o bien
    `{;error, :sin_recursos}` si no hay recursos disponibles.

  - `{:release, from, recurso}`, que devuelve un `recurso` previamente
    solicitado por `from`, devuelve `:ok` si la operación se lleva
    a cabo con éxito y el recurso queda disponible para nuevas
    asignaciones, o `{:error, :recurso_no_reservado}` si el recurso no había
    sido asignado al proceso `from`.

  - `{:avail, from}`, que devuelve un entero con el número de recursos
    disponibles en el servidor.


## Otras consideraciones y requisitos

- Cada recurso se modela como un átomo. En el momento de iniciar el
  servidor, se le proporciona la lista de recursos disponibles
  inicialmente, p.e. `[:a, :b, :c, :d]`.

- Los recursos se asignan en un orden arbitrario.

- Para facilitar la interacción con el servidor, el proceso gestor se
  registra con el nombre `gestor`.

- El módulo ofrece una función `start/1` que inicia el gestor y lo
  registra con el nombre especificado.

- El módulo ofrece a los clientes un API con las funciones `alloc/0`,
  `release/1`, `avail/0` que encapsulan la interacción con el
  servidor.

- Como se indica anteriormente el gestor debe comprobar que el proceso
  que devuelve un recurso es el que, efectivamente, reservo el
  recurso.
  
  ```elixir
	iex(10)> pid = self().	# Pid ligado a la identidad del shell
	<0.44.0>
	iex(11)> spawn(fn () -> {:ok, r} = gestor:alloc(),
	                         pid ! r
	               end)
	<0.34.0>
	iex(12)> receive, do a -> gestor:release(a) end
	{:error, :recurso_no_reservado}
  ```
  
  Respecto al ejemplo anterior, tenga cuidado ya que la shell es un
  proceso elixir que termina cuando se produce un error, creándose un
  nuevo proceso shell.


## Iteraciones

1. Versión no distribuida

  El gestor y los clientes se ejecutan en un mismo nodo.
  
2. Versión distribuida

  - Los clientes se ejecutan en nodos distintos a los del gestor.
  
  - El proceso gestor se debe registrar globalmente en la máquina
    distribuida de manera que este accesible para todos los nodos.
	
3. Versión tolerante a fallos

  Los procesos cliente que han reservado un recurso pueden fallar
  antes de liberarlo, en cuyo caso el recurso no se recuperaría nunca.
  
  En este iteración el gestor tiene que recuperarse de estos fallos.
  
  :warning: Puede fallar un proceso cliente o puede fallar el nodo en
  que se ejecuta.
