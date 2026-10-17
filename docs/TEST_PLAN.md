# Plan de pruebas — Fronteras de Hierro

## Principios

- La lógica del juego se prueba **sin interfaz**, con scripts de GDScript ejecutables en modo headless.
- Cada hito del `ROADMAP.md` añade sus pruebas; no se cierra un hito con pruebas fallidas.
- Los informes distinguen siempre entre pruebas **ejecutadas** y **no verificadas**.

## Pruebas automáticas

Scripts propios en `tests/`, sin plugins (decisión abierta nº 7 del GDD). Cada ejecutable termina con código 0 si pasa todo y 1 si algo falla.

**Comando (desde la raíz del proyecto; sustituye `godot` por tu ejecutable de Godot 4.7):**

```
godot --headless --path . --script res://tests/test_province_data.gd
godot --headless --path . --script res://tests/test_province_selection.gd
```

**Estado:** `tests/test_province_data.gd` (A-01 a A-04 y A-29) y `tests/test_province_selection.gd` (A-06 a A-08 y A-30 a A-36) están escritos pero **aún no se ha ejecutado en Godot** (no hay ejecutable en la nube). Solo se ha comprobado una réplica de la lógica en Python sobre los mismos datos; no cuenta como validación en Godot. Resultado en el PC del propietario: pendiente.

| ID | Hito | Qué comprueba | Resultado esperado |
|---|---|---|---|
| A-01 | 1 | Número de provincias | Exactamente 14 |
| A-02 | 1 | Ids, nombres, propietarios y geometría | Ids únicos, no vacíos y ASCII; nombres no vacíos; propietario válido con reparto 7-7; polígonos con ≥ 3 vértices, dentro de la ventana, con área y triangulables |
| A-03 | 1 | Vecinos | Todos existen; sin autovecinas ni duplicados; adyacencia simétrica |
| A-04 | 1 | Conectividad | Un recorrido desde cualquier provincia alcanza las 14 |
| A-29 | 1 | Topología y geometría coinciden | Dos provincias son vecinas si y solo si comparten una arista dibujada |
| A-06 | 2 | Propiedad inicial y datos intactos | 14 provincias, 7 contra 7, etiquetas "Jugador"/"Enemigo"; la selección no modifica los datos |
| A-07 | 2 | Selección por punto interior | El centro y puntos interiores de cada provincia devuelven su id |
| A-08 | 2 | Puntos exteriores | Fuera de la ventana, márgenes y esquina recortada del mapa devuelven "" |
| A-30 | 2 | Cerca de fronteras | A 1 px de cada frontera compartida, cada lado devuelve su provincia; sobre la frontera exacta el resultado es estable y nunca una tercera provincia |
| A-31 | 2 | Cambio de selección | Seleccionar otra provincia actualiza `selected_id` y emite `selection_changed`; repetir no emite |
| A-32 | 2 | Limpiar selección | Un punto vacío deja `selected_id` en "" y emite la señal una vez |
| A-33 | 2 | Transformación del mapa | Con el nodo movido, escalado y rotado, convertir un punto global a local selecciona la provincia correcta |
| A-34 | 2 | Panel: contenido | Nombre, propietario, recuento y nombres de vecinas coinciden con los datos para las 14 provincias |
| A-35 | 2 | Panel: estado vacío | Sin selección se muestra la invitación y no los detalles; `build_info` de un id inexistente devuelve vacío |
| A-36 | 2 | Escena principal | `main.tscn` carga y conecta el mapa con el panel |
| A-09 | 3 | Ataque válido | Aceptado: origen propio, destino adyacente enemigo, tropas suficientes |
| A-10 | 3 | Ataque a no adyacente | Rechazado |
| A-11 | 3 | Ataque a provincia propia | Rechazado |
| A-12 | 3 | Ataque desde provincia ajena | Rechazado |
| A-13 | 3 | Ataque sin tropas suficientes | Rechazado |
| A-14 | 3 | Combate: atacante mayor | Gana con N − D tropas |
| A-15 | 3 | Combate: atacante menor | Pierde; defensor queda con D − N |
| A-16 | 3 | Combate: igualdad | Gana el defensor con 0 de excedente (regla del GDD) |
| A-17 | 3 | Determinismo | 100 repeticiones con las mismas entradas dan el mismo resultado |
| A-18 | 4 | Cambio de dueño | Tras victoria, dueño nuevo y tropas restantes correctas |
| A-19 | 4 | Sin cambio tras derrota | El dueño no cambia |
| A-20 | 4 | Integridad de propiedad | Tras N ataques, cada provincia tiene un único dueño |
| A-21 | 5 | Validez de la IA | Todas las órdenes de la IA son aceptadas |
| A-22 | 5 | Determinismo de la IA | Mismo estado → misma decisión |
| A-23 | 5 | Escenario fijo | La IA ataca a la vecina débil esperada |
| A-24 | 5 | Sin opciones | Si no hay ataque posible, la IA no hace nada ni falla |
| A-25 | 6 | Victoria | Enemigo sin provincias → fin con victoria |
| A-26 | 6 | Derrota | Jugador sin provincias → fin con derrota |
| A-27 | 6 | Órdenes tras el fin | Rechazadas |
| A-28 | 6 | Reinicio | El estado vuelve exactamente al inicial |

Nota: los resultados de A-14 a A-16 dependen de la regla de combate del GDD (suposición); se ajustarán si el propietario la cambia.

## Pruebas manuales

Se realizan en Godot 4.7 en un PC con Windows.

| ID | Hito | Pasos | Resultado esperado |
|---|---|---|---|
| M-01 | 0 | Importar `project.godot` y abrirlo | Sin errores ni avisos al cargar |
| M-02 | 0 | F5 | Ventana 1280x720 con título "FRONTERAS DE HIERRO" y subtítulo "Prototipo temprano" |
| M-03 | 0 | Redimensionar la ventana | El contenido sigue centrado y legible |
| M-04 | 1 | Ejecutar (F5) y observar el mapa | 14 provincias visibles, sin huecos ni solapes, con fronteras oscuras y los 14 nombres legibles; 7 azules (jugador) y 7 rojas (enemigo); leyenda "Jugador: 7 / Enemigo: 7" y "Provincias: 14"; título y subtítulo visibles; sin errores en la consola |
| M-05 | 2 | Clic izquierdo en una provincia (propia o enemiga) | Se resalta con contorno claro, conserva su color y el panel muestra nombre, propietario y vecinas |
| M-06 | 2 | Clic en otra provincia | La selección y el panel cambian de inmediato |
| M-07 | 2 | Clic en una zona vacía del mapa (p. ej. la esquina inferior derecha o el fondo) | Se limpia la selección y el panel invita a seleccionar |
| M-07b | 2 | Clic sobre el panel de información | La selección no cambia |
| M-07c | 2 | Clics repetidos cerca de fronteras | Siempre se selecciona una de las dos provincias vecinas (o ninguna si cae justo en el borde), sin errores en la consola |
| M-07d | 2 | Revisión visual del panel | Panel a la derecha sin tapar nombres del mapa; texto legible; sin botones de acción |
| M-08 | 3 | Atacar provincia adyacente enemiga | Combate resuelto; tropas actualizadas |
| M-09 | 3 | Intentar atacar provincia no adyacente | Rechazado con mensaje o sin efecto |
| M-10 | 4 | Ganar un ataque | La provincia cambia de color |
| M-11 | 5 | Dejar la partida 2 minutos sin actuar | El enemigo ataca; sin errores |
| M-12 | 6 | Conquistar todas las provincias enemigas | Aparece "Victoria" |
| M-13 | 6 | Perder todas las provincias | Aparece "Derrota" |
| M-14 | 6 | Reiniciar tras el fin | Partida nueva con el estado inicial |

## Pruebas del hito 0 (cimientos)

| Comprobación | Cómo | Estado |
|---|---|---|
| `project.godot` apunta a `res://scenes/main.tscn` | Revisión estática | Hecho en la nube |
| La escena existe y su formato es coherente | Revisión estática | Hecho en la nube |
| Carga sin errores en Godot 4.7 | M-01, M-02, M-03 | **Pendiente** (requiere Godot) |

## Estado del hito 1 (mapa y provincias)

| Comprobación | Cómo | Estado |
|---|---|---|
| Hito 0 en Godot 4.7.2 / Windows | M-01, M-02 | Validado por el propietario (informe del usuario) |
| Datos del mapa (14 provincias, 7-7, vecinos simétricos, conexo, aristas compartidas) | Réplica en Python de las comprobaciones sobre `province_data.gd` | Ejecutado en la nube: correcto. No sustituye a Godot |
| `tests/test_province_data.gd` | Comando de arriba | **Pendiente** en Godot (PC del propietario) |
| Aspecto del mapa | M-04 | **Pendiente** (nadie lo ha visto ejecutándose) |

## Estado del hito 2 (selección e información)

| Comprobación | Cómo | Estado |
|---|---|---|
| Lógica de selección (centros, puntos descentrados, vecindades, bordes, exteriores) | Réplica en Python sobre los datos reales | Ejecutado en la nube: correcto. No sustituye a Godot |
| `tests/test_province_selection.gd` | Comando de arriba | **Pendiente** en Godot (PC del propietario) |
| `tests/test_province_data.gd` | Comando de arriba | **Pendiente** en Godot (PC del propietario) |
| Aspecto, clics reales y panel | M-05 a M-07d | **Pendiente** (nadie lo ha visto ejecutándose) |
