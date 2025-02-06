# Pool de trabajadores

En este ejercicio implementaremos un sistema con un _pool de
trabajadores_.


## Descripción

- El sistema dispone de un número arbitrario de _trabajadores_, que son
  procesos capaces de hacer un trabajo específico.
  
- Existe un proceso coordinador que registra todos los trabajadores
  disponibles: _pool de trabajadores_.
  
- Cuando el coordinador recibe un lote de trabajos, los reparte entre
  los distintos trabajadores y a continuación recopila los resultados
  de cada uno de ellos y devuelve el conjunto de resultados al
  cliente.
  

# Opciones

Este ejercicio tiene distintos niveles de dificultad que podemos
configurar eligiendo entre las distintas opciones:

  - Si el número de trabajos en el lote es mayor que el número de
    trabajadores, el servidor devuelve un error `{:error,
    :lote_demasiado_grande}`.

  - Si el número de trabajos en el lote es mayor que el número de
    trabajadores, el servidor reparte todos los trabajos posibles y
    esperar a que los trabajadores vayan terminando para asignarles
    los trabajos pendientes.

  - El servidor termina de procesar un lote de trabajos antes de
    procesar el siguiente.
  
  - El servidor puede procesar varios lotes simultáneos.

  - Los resultados no siguen ningún orden.

  - Los resultados siguen el orden del lote de trabajos.


## Requisitos

Implemente el sistema en dos módulos: `Trabajador` y `Servidor`. El
primero proporciona la implementación de los trabajadores y el segundo
del proceso coordinador y el api externo para los clientes.


## Módulo `Trabajador`

Crea un proceso `Trabajador` que recibe los siguientes mensajes:


  - `{:trabajo, from, func}`, ejecuta la función `func` y devuelve a
    `from` el resultado. De ser necesario el mensaje podría tener más
    elementos.
	
  - `:stop`, termina el proceso.
  
  
## Módulo `Servidor`

Crea un proceso `Servidor` que recibe los siguientes mensajes:

  - `{:trabajos, from, trabajos}`, donde `trabajos` es una lista de
    funciones.
	
  - `{:stop, from}`, manda el mensaje `:stop` a todos los
    trabajadores, devuelve `:ok` a `from` y termina.

Al inicio, el proceso `Servidor` debe crear `n` trabajadores. Siendo
`n` un parámetro del servidor.