# Micro Bank

En este ejercicio el objetivo es aprender a usar algunas herramientas
de desarrollo básicas que nos ofrece el lenguaje y su librería
estándar.

## Descripción del micro bank

El micro bank es un servidor sencillo que guarda una lista de
cuentas. Cada cuenta indica el nombre de la persona dueña de la cuenta
y el saldo disponible.  El servidor ofrece los siguientes servicios:

  - `stop`, para detener el servidor.
  
  - `deposit, who, amount`, deposita la cantidad indicada en la cuenta
    de `who`.

  - `ask, who`, solicita el saldo de la cuenta de `who`.

  - `withdraw, who, amount`, retira la cantidad indicada de la cuenta
    de `who`.


## Mix

Estudie la documentación de la herramienta `mix` y cree un proyecto
para el desarrollo del ejercicio.

> :warning: No olvide consultar la documentación de `iex -S mix`.


## gen_server

Estudie la documentación del behaviour `gen_server` de la librería
estándar e implemente el ejercicio usando dicho behaviour.


## supervisor

Estudie la documentación del behaviour `supervisor` de la librería
estándar. Usando dicho behaviour añada un mecanismo de tolerancia a
fallos que reinicie el servidor cuando el proceso falle.


## Testing

Implemente tests que comprueben el comportamiento del servidor y tests
que comprueben el funcionamiento del supervisor.

> :warning: Recuerde que los tests se ejecutan con `mix test`.



