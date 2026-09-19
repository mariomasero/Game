# Plan de desarrollo — Del laboratorio de pueblo a la corporación biotecnológica

Actualizado: 19 de septiembre de 2026.

> **Uso por agentes de desarrollo:** ejecutar una tarea observable cada vez; consultar `AGENTS.md`, el diseño vigente y este plan antes de implementar. Usar `superpowers:executing-plans` si está disponible. Este documento organiza el desarrollo; no autoriza ejecutar todos los hitos de una vez.

**Objetivo:** construir una progresión jugable desde un laboratorio de una persona hasta una corporación, conectando encargos, producción, investigación, construcción modular y relaciones con el pueblo.

**Arquitectura prevista:** conservar el mundo 3D con personajes 2D y cámara elevada de orientación fija. Construir los escenarios mediante tilesets modulares, mantener los equipos interactivos como escenas independientes y separar las reglas del negocio, la distribución del laboratorio y el guardado de su representación visual.

**Tecnología:** Godot 4.6; el historial documenta 4.6.2. GDScript tipado, partida individual local, PC con teclado y ratón como objetivo inicial y exportación Windows ya registrada. Verificar el ejecutable y el repositorio reales antes de desarrollar.

**Diseño de referencia:** texto completo «Diseño principal — Del laboratorio de pueblo a la corporación biotecnológica», fechado el 17 de septiembre y aportado por el usuario en esta conversación. En el repositorio, su nombre canónico será `GAME_DESIGN.md`. Esta revisión incorpora además la petición expresa de construcción modular y escenarios desarrollados con tilesets.

**Alcance de esta entrega:** reescritura documental y conservación del historial. No se ha inspeccionado ni ejecutado el repositorio del juego; las implementaciones y pruebas mencionadas como existentes proceden del registro recibido.

## 1. Visión y reglas que guían el desarrollo

El protagonista llega de fuera, abre un pequeño laboratorio y conoce el pueblo resolviendo necesidades. La producción sostiene el negocio; la investigación abre posibilidades; la reinversión transforma esas posibilidades en equipos, espacios, personal e instalaciones visibles.

**Bucle principal:** atender encargos → producir y ganar dinero → investigar y reinvertir → conseguir nuevas capacidades → acceder a problemas y oportunidades mayores.

La experiencia mantiene el control directo del personaje. Las interfaces se abren desde los equipos y lugares pertinentes; el crecimiento no debe convertir automáticamente el juego en un conjunto de menús separados del mundo.

Reglas globales:

- Cada escalón aporta una capacidad, aplicación, decisión o delegación reconocible. Una mejora de velocidad puede ser útil, pero no basta para demostrar la promesa completa del juego.
- El jugador puede mantener ingresos mientras investiga o ahorra. Las esperas dejan espacio a otras actividades.
- Los procedimientos dominados se simplifican gradualmente. Los productos y clientes antiguos conservan utilidad.
- El laboratorio, sus personas y sus espacios conservan su historia cuando la empresa crece.
- Ciencia coherente, pocas variables visibles y resultados comprensibles; tiempos y operaciones simplificados. El juego debe funcionar sin formación científica previa.
- Tono acogedor, humor negro y extrañeza gradual. La ruta responsable permite prosperar; no hay maldad obligatoria ni un medidor moral como requisito.
- Las referencias a Stardew Valley, Graveyard Keeper 2 y la fantasía corporativa tipo Umbrella orientan la experiencia; personajes, historia, arte y sistemas tendrán identidad propia.
- Mantener los sprites originales y las ocho direcciones que el historial ya registra. No regresar a cuatro direcciones por seguir un texto antiguo.
- Mantener cámara de orientación fija, profundidad real, movimiento XZ e interfaz legible. Sin rotación libre del jugador ni cambio de arquitectura visual por rutina.
- La autoría de escenarios usará tilesets desde H6. La construcción por el jugador tendrá su propio alcance incremental, desde H7.
- Estado persistente con IDs estables y versión de formato. Sin avance offline. Pausa y modo de construcción detienen el tiempo de simulación.
- Implementar con recursos nativos suficientes; evaluar plugins gratuitos solo ante una necesidad concreta y comprobar licencia, mantenimiento y compatibilidad antes de adoptarlos.

## 2. Estado real de partida

La tabla resume la documentación disponible hasta el 17 de septiembre. «Registrado» significa que existe evidencia descrita en el historial, no que se haya repetido durante esta actualización.

| Área | Estado registrado | Trabajo que sigue abierto |
|---|---|---|
| H0 — Dirección | Enfoque 3D definido; visión de laboratorio a corporación acordada posteriormente | Sincronizar documentos operativos al retomar el repositorio |
| H1 — Sala y arte | Sala 3D activa, personaje con ocho direcciones, terminal GLB, interacción y capturas | Recorrido humano, aceptación visual y estabilidad durante movimiento |
| H2 — Primer pedido | Compras, producción, recogida, entrega y devolución de insumos | Valorar comprensión y diversión con juego humano |
| H3 — Progreso persistente | Mejora de calibración, guardado, recuperación y pruebas | Mantener estas garantías al introducir nuevos estados |
| H4 — Versión exportada | Avisos, sonido, guía y exportación Windows; prueba técnica de continuidad | Prueba humana sin instrucciones verbales y sesiones prolongadas |
| Investigación | No consta implementada | Primera pregunta, comparación y desbloqueo |
| Tilesets de escenario | Consta geometría modular y un GLB; no consta un sistema de tilesets validado | Catálogo, reglas de encaje y una muestra recorrible |
| Construcción del jugador | No consta implementada | Colocación en cuadrícula y ampliación de espacios |
| Pueblo, NPC y personal | No constan implementados | Introducción gradual después de validar el primer tramo |

### Base económica y técnica que se conserva

- Producto provisional ficticio: muestra Lumen. Insumos: matriz y catalizador.
- Balance registrado: 120 cr iniciales; insumos de un lote 12 + 8 cr; entrega de 35 cr; lote de 12 segundos.
- Calibración: 100 cr después de tres pedidos; lotes nuevos de 8 segundos. Esta mejora demuestra reinversión, pero todavía no desbloquea una actividad distinta.
- Producción e inventario separados de la UI mediante `LabDefinitions` y `LabSession`, según el historial.
- Guardado en `user://lab_save.json`, con validación, escritura temporal, recuperación explícita y sin producción offline. El historial de H4 conserva `schema_version = 1`.
- Exportación registrada: `builds/windows/Biotech.exe` y `Biotech.pck`. El aviso de audio del arnés se documentó como corregido el 17 de septiembre; no se conserva como incidencia activa.
- La medición de rendimiento registrada dura 186,58 segundos sobre un equipo concreto. No acredita sesiones de horas ni rendimiento en equipos modestos.

No reiniciar H1–H3 ni reconstruir lo ya registrado sin inspeccionar su estado actual. Las cifras de pruebas son históricas, pertenecen a entregas distintas y no deben sumarse para inventar una suite vigente.

## 3. Alcance y secuencia de entregas

Se mantienen H0–H4 para poder interpretar el historial. El antiguo H5 se concreta como validación de la base; el antiguo H6 genérico se sustituye por hitos explícitos H6–H14. Sus menciones dentro del archivo histórico conservan el significado que tenían en su fecha.

| Hito | Entrega | Dependencia principal | Situación |
|---|---|---|---|
| H0–H4 | Base recorrible, negocio, guardado y exportación | Repositorio existente | Implementación registrada; cierres humanos pendientes |
| H5 | Comprensión y prioridades de mejora de la base | H1–H4 disponibles para jugar | Pendiente |
| H6 | Laboratorio y muestra exterior construidos con tilesets | Base visual e interacción preservadas | Pendiente |
| H7 | Colocar y reorganizar equipos en cuadrícula | H6 y guardado existente | Pendiente |
| H8 | Primera escalada: necesidad → investigación → equipo → nueva oportunidad | H5, H7 y economía existente | Pendiente |
| H9 | Pueblo pequeño con clientes recurrentes | H8 y kit exterior de H6 | Planificado |
| H10 | Ampliar y especializar habitaciones | H7–H9 | Planificado |
| H11 | Delegar una tarea dominada en un empleado | H10 y producción comprensible | Visión posterior |
| H12 | Conectar procesos y especialidades | H11 | Visión posterior |
| H13 | Corporación con varias instalaciones y consecuencias regionales | H12 | Visión posterior |
| H14 | Consolidación y preparación de una versión distribuible del alcance elegido | Hitos incluidos en esa versión | Transversal; cierre posterior |

**Objetivo cercano:** validar una pequeña escalada completa, con un equipo que el jugador compra, coloca y utiliza para hacer algo nuevo. No construir ahora toda la corporación.

H6 puede prepararse con piezas provisionales mientras se recoge feedback de H5. La falta de una valoración humana no se transforma en una aprobación tácita: se registra y limita la expansión de contenido. No se fija un calendario de semanas sin inspeccionar código, disponibilidad y velocidad de producción de arte.

## 4. Escenarios mediante tilesets

### 4.1. Interpretación técnica dentro de la dirección acordada

Se conserva el mundo 3D con texturas pixel art, personajes 2D y cámara elevada fija. **Tileset** significa aquí un catálogo de piezas reutilizables que encajan en una cuadrícula: suelos, caminos, bordes, paredes, esquinas, huecos y cubiertas. Las superficies pueden usar atlas de texturas; el volumen se resuelve con mallas sencillas.

La opción inicial a probar para geometría estática es `GridMap` con `MeshLibrary`. Godot lo ofrece para construir niveles 3D mediante mallas colocadas en cuadrícula, con colisiones y navegación. No es un contenedor general de nodos interactivos: máquinas, puertas funcionales y terminales seguirán siendo escenas propias. [Documentación oficial de Godot 4.6: GridMaps](https://docs.godotengine.org/en/4.6/tutorials/3d/using_gridmaps.html).

Esto es una propuesta de implementación para cumplir tilesets sin abandonar el 3D existente. H6 decidirá si basta el flujo nativo o si alguna pieza necesita una escena modular adicional. Una futura petición explícita de mundo enteramente 2D requeriría revisar representación y física; no se presupone en este plan.

### 4.2. Separar autoría del mapa y construcción jugable

| Trabajo | Quién lo realiza | Alcance |
|---|---|---|
| Diseñar pueblo, exteriores e interiores | Desarrollador mediante tilesets en el editor | Mapas pequeños hechos a mano y reutilizables |
| Distribuir equipos | Jugador en modo construcción | Solo dentro de superficies habilitadas y propias |
| Ampliar laboratorio | Jugador mediante módulos desbloqueados | Habitaciones y conexiones válidas; H10 |
| Decorar | Jugador cuando exista el catálogo | Variantes visuales y mobiliario; no necesario para H8 |

No todo objeto dibujado con un tile será editable por el jugador. Un camino público o la casa de un NPC pueden formar parte de un tileset sin ser construibles. No se incluye generación procedural del pueblo.

### 4.3. Contrato de piezas y capas

- Una celda lógica compartida por suelo, huellas de equipos y módulos. Probar 1 unidad por celda como referencia heredada, validando paso y proporciones antes de fijarla.
- Cada pieza tiene ID estable, categoría, tamaño en celdas, origen, orientaciones permitidas y reglas de encaje. No guardar índices internos del atlas o de la biblioteca como identidad permanente.
- Capas lógicas: terreno/suelo; estructura y límites; objetos funcionales; decoración; marcadores y previsualizaciones. No todas tienen que convertirse en un `GridMap` distinto.
- Un mismo esquema de origen y alturas evita huecos, solapes y z-fighting. Las paredes y puertas deben coincidir con los límites de las superficies transitables.
- Variantes visuales de un suelo conservan sus reglas de tránsito. La decoración solo bloquea si su definición lo indica.
- Diseñar bordes y esquinas interiores/exteriores de césped/camino; repetir un único bloque elevado en cada celda no debe convertir el pueblo en una sucesión de plataformas.
- Empezar seleccionando variantes a mano. Un sistema automático de conexiones solo se añade cuando la muestra demuestra que reduce trabajo real.
- Mantener densidad de textura, paleta, escala, pivotes, perspectiva de los detalles pintados y luz coherentes. Una imagen de referencia requiere adaptación y revisión de encaje antes de ser tile de producción.

### 4.4. Primeros kits

| Kit | Piezas mínimas de la muestra | Uso inicial |
|---|---|---|
| Interior | Suelo, pared recta, esquina, remate y hueco de puerta | Reconstruir la envolvente del laboratorio |
| Exterior | Césped, camino, borde, esquina y umbral de entrada | Tramo corto recorrible junto al edificio |
| Fachada | Base de pared, esquina, puerta y remate superior | Identificar el laboratorio desde fuera |
| Funcional | Terminal y máquina existentes; marcador de equipo nuevo | Objetos independientes alineados con la cuadrícula |

Producir solo variantes necesarias para estas muestras. Conservar fuentes editables y atribuciones. Blender, un editor pixel art y herramientas auxiliares pueden producir piezas; ninguna compra ni generación con IA es requisito para cerrar el hito.

## 5. Construcción modular como mecánica

### 5.1. Progresión de la construcción

1. **H7: distribuir equipos.** Colocar, mover, girar y guardar objetos dentro de la sala existente.
2. **H8: comprar una capacidad.** Instalar un equipo nuevo como parte de una investigación y un encargo.
3. **H10: ampliar espacio.** Recuperar una habitación o añadir un módulo conectado, con coste y requisito visibles.
4. **H10 en adelante: especializar.** Dedicar espacios a producción, análisis o almacenamiento según necesidades comprobadas.
5. **H13: abrir otra instalación.** Reutilizar las reglas ya probadas, con identidad y gestión propias.

El primer sistema es construcción por cuadrícula y módulos, con un solo nivel. No incluye dibujo libre de edificios, plantas superpuestas, terraformación ni redes físicas de tuberías/cableado.

### 5.2. Flujo de uso y reglas iniciales

- Entrar en modo construcción desde una acción visible; pausar la simulación y bloquear producción manual e interacción normal mientras se edita.
- Elegir objeto, mostrar huella y zona frontal de uso, mover la previsualización, girar en pasos de 90° cuando la definición lo permita y confirmar o cancelar.
- Mostrar validez mediante forma/icono y texto, además del color. Indicar causas concretas: fuera de parcela, espacio ocupado, saldo insuficiente o acceso bloqueado.
- Comprobar propiedad, desbloqueo, superficie compatible, ocupación, coste y accesibilidad antes de confirmar.
- Reservar entrada, punto de aparición y zona de salida del modo construcción. No construir sobre el personaje ni encerrarlo.
- Validar un recorrido de anchura suficiente desde la entrada a las zonas de uso de equipos esenciales. La comprobación en celdas debe representar el tamaño real del personaje y contrastarse con colisiones del juego.
- Aplicar coste, ocupación e instancia en una sola operación de estado. Cancelar no consume dinero ni materiales. Repetir una confirmación no crea dos objetos.
- Mover conserva identidad, mejoras y contenido; en el primer alcance solo se permite con el equipo vacío y sin trabajo reservado. Un lote produciendo o listo impide mover o almacenar la máquina.
- Mover equipos ya comprados no cuesta dinero al principio. Retirarlos los envía al almacén de mobiliario; no los destruye ni da reembolso en efectivo. Se excluye reventa hasta diseñar su balance.
- Mantener disponible al menos una vía de producción/ingresos y el acceso al terminal. No permitir almacenar un equipo esencial si su retirada deja la partida sin esa vía.
- Guardar tras cada operación confirmada. Reutilizar el comportamiento existente ante fallo de escritura: pausar, conservar estado en memoria y ofrecer reintento; no volver a cobrar al reintentar.

### 5.3. Ampliaciones en H10

La primera ampliación será un módulo de habitación adyacente o la recuperación de un espacio cerrado. Tendrá tamaño, conector, precio y condición de desbloqueo definidos como datos. La previsualización muestra la distribución final y el paso entre salas.

Confirmar la ampliación modifica conjuntamente propiedad, suelo, paredes, puerta de conexión y saldo. Rechazar solapes o conexiones que dejan zonas inaccesibles. La primera versión no permite demoler habitaciones habitadas o con equipos; las variantes cosméticas no alteran capacidad por accidente.

Las obras se completarán al confirmar en la primera versión. Solo se añadirá duración si ofrece una decisión útil y otras actividades durante la espera. Ampliar espacio debe posibilitar un uso concreto, como una segunda estación o una zona de análisis.

## 6. Arquitectura y persistencia proporcionales

### 6.1. Responsabilidades

| Componente | Responsabilidad | Límite |
|---|---|---|
| Definiciones de contenido | Artículos, recetas, equipos, investigaciones, clientes y módulos con IDs | No contienen el progreso mutable de una partida |
| Sesión del negocio | Saldo, inventario, trabajos, pedidos y desbloqueos | No depende de botones ni mallas |
| Estado espacial | Propiedad, celdas, conectores e instancias colocadas | No usa la apariencia del tile como regla de juego |
| Construcción | Previsualizar, validar y confirmar operaciones espaciales | No cobra ni modifica inventario por su cuenta fuera de la transacción |
| Presentación del mundo | Representar mapas y equipos, colisiones e interacción | Puede reconstruirse a partir del estado |
| Investigación | Preguntas, evidencias, intentos y resultados desbloqueados | No otorga recompensas repetidas por el mismo hallazgo |
| Persistencia | Snapshot completo, validación, migración y recuperación | No sobrescribe una partida inválida con una vacía |

Partir de `LabDefinitions` y `LabSession`; extraer responsabilidades cuando la nueva mecánica lo necesite. No crear de antemano un gestor global para toda la corporación.

### 6.2. Rutas orientativas para las tareas nuevas

Son ubicaciones propuestas, no afirmaciones sobre archivos existentes. Al abrir el repositorio se ajustarán al patrón real sin mover archivos por estética.

| Hito | Rutas propuestas | Contenido |
|---|---|---|
| H6 | `assets/source/tilesets/`, `assets/game/tilesets/`, `resources/tilesets/` | Fuentes, atlas/mallas y catálogos |
| H6 | `scenes/world/tileset_sample.tscn` | Muestra interior/exterior y revisión de uniones |
| H7 | `scripts/domain/build_layout.gd`, `scripts/domain/build_rules.gd` | Estado espacial y validación de colocación |
| H7 | `scenes/ui/build_menu.tscn`, `scripts/systems/build_controller.gd` | Selección, previsualización y entrada |
| H7 | `resources/definitions/buildables/` | Costes, huellas, giros y accesos |
| H8 | `scripts/domain/research_progress.gd`, `resources/definitions/research/` | Primera investigación y evidencias |
| H9 | `scenes/world/village.tscn`, `resources/definitions/clients/` | Pueblo reducido y clientes |
| H10 | `resources/definitions/room_modules/` | Habitaciones y conectores |
| H5–H14 | `docs/decisions/`, `docs/PRUEBA_JUGABLE.md`, `tests/` | Decisiones, observaciones y verificaciones de reglas |

### 6.3. Extensión del guardado

Desde H7, cada objeto colocado necesita `instance_id`, `definition_id`, `location_id`, celda de origen, orientación y referencia a su estado de trabajo/mejoras. Dos máquinas del mismo modelo deben poder tener trabajos distintos.

Desde H8 se guardan evidencias, resultados de investigación, capacidades y pedidos desbloqueados. H9 añade relaciones y estado del mundo; H10, módulos de habitación y propiedad. Añadir cada bloque cuando se implementa su hito, no diseñar ahora todos los datos de H13.

La primera migración espacial debe reconstruir el laboratorio antiguo en su distribución original, asignar identidad a terminal y máquina existentes y conservar saldo, lote, mejora y pedidos. No exigir partida nueva para probar construcción.

El snapshot incluye conjuntamente economía, disposición y trabajos. Al cargar se valida antes de instanciar el mundo: IDs conocidos, huellas válidas, ausencia de duplicados y accesos seguros. Una definición ausente o una distribución inválida provoca recuperación o migración explícita; no elimina contenido silenciosamente.

Al introducir varias escenas en H9, el estado del negocio deja de depender de que el laboratorio esté cargado: los trabajos avanzan con el tiempo activo de la sesión y quedan congelados en pausa, construcción y cierre. Cambiar de escena no reinicia ni completa un lote dos veces. Elegir el mecanismo compartido más pequeño que permita esto.

## 7. Hitos y criterios de salida

### H0–H4 — Conservar y cerrar la base existente

**Entrega:** continuar desde el prototipo documentado y resolver sus cierres pendientes.

- [ ] Inspeccionar versión, Git, escena principal, exportación y pruebas reales; registrar divergencias frente al historial.
- [ ] Conservar fuentes, personaje aprobado, arte e interacciones existentes.
- [ ] Recorrer manualmente sala, bordes y mobiliario; revisar pies, profundidad, colisiones, parpadeo y redimensionado.
- [ ] Completar compra, lote, recogida, entrega, mejora y continuación de partida en la versión exportada.
- [ ] Registrar por separado fallos técnicos, problemas de comprensión y valoración artística.

**Salida:** base reproducible con limitaciones explícitas. No se exige rehacer la migración 3D ni volver a exportar un binario idéntico solo para documentarlo.

### H5 — Validar comprensión, ritmo y siguiente objetivo

**Entrega:** una prueba humana breve de la base, seguida de cambios pequeños sobre los problemas observados.

- [ ] Pedir a una persona que complete un pedido y busque la mejora sin instrucciones verbales; usar la guía escrita del juego.
- [ ] Registrar primer atasco, comprensión de insumos y recompensa, utilidad de la espera y motivo para seguir.
- [ ] Repetir con 3–5 personas si están disponibles; identificar observación, interpretación y cambio propuesto.
- [ ] Corregir los dos problemas que más bloquean la experiencia y repetir el recorrido afectado.

**Salida:** el jugador puede explicar cómo gana dinero, qué quiere comprar y para qué. Documentar si la rutina resulta repetitiva. La identidad central ya está acordada: el resultado sirve para ajustar ritmo y claridad, no para volver a elegir el género.

**Fuera de alcance:** telemetría remota, estudios masivos o introducir contratos moralmente opuestos como condición de éxito.

### H6 — Tilesets para laboratorio y exteriores

**Entrega:** un kit mínimo reutilizable y una muestra que conserva las interacciones existentes.

- [ ] Medir módulo, personaje y pasillos actuales; fijar cuadrícula, origen y densidad de textura en una ficha visual.
- [ ] Crear suelo, pared, esquina y hueco de puerta del laboratorio con geometría y texturas provisionales coherentes.
- [ ] Probar el flujo `MeshLibrary`/`GridMap` para piezas estáticas y conservar terminal/máquina en escenas propias.
- [ ] Sustituir la envolvente de la sala manteniendo posiciones y funcionalidad del prototipo; revisar uniones y colisiones.
- [ ] Añadir una muestra corta de césped, camino, transición y entrada, sin desarrollar aún el pueblo.
- [ ] Reimportar una pieza modificada y comprobar que mantiene identidad y no obliga a reconstruir el mapa.

**Salida:** se pueden pintar dos distribuciones distintas con el mismo kit; el personaje cruza uniones sin engancharse ni caer, y las transiciones se leen con la cámara real. Los objetos funcionales siguen funcionando.

**Primera tarea de este hito:** sustituir únicamente el suelo por piezas repetibles y comprobar encaje, escala y recorrido. Después abordar paredes y exterior.

### H7 — Construcción inicial: colocar y reorganizar equipos

**Entrega:** modo construcción usable en la sala actual, con una mesa auxiliar provisional como primera pieza nueva.

- [ ] Representar ocupación, propiedad y accesos de la sala existente sin alterar su apariencia.
- [ ] Implementar previsualización de una pieza, confirmación/cancelación y giro solo cuando proceda.
- [ ] Añadir validación de huella, coste, acceso y colisiones; explicar el rechazo antes de cobrar.
- [ ] Permitir mover y almacenar piezas vacías según las reglas de la sección 5.
- [ ] Extender y migrar guardado; conservar identidad y mejoras al mover equipos.
- [ ] Probar desde una partida anterior y desde una nueva.

**Salida:** colocar una mesa, cambiarla de sitio, cancelar otra compra, guardar y recargar sin duplicados, pérdidas ni acceso bloqueado. Intentar bloquear la puerta o mover una máquina con lote debe rechazarse sin modificar la partida.

**Pruebas de reglas:** en `tests/test_build_rules.gd`, cubrir pieza fuera de parcela, huella girada, intersección, acceso obstruido y fondos insuficientes. En `tests/test_build_persistence.gd`, cubrir migración, recarga, confirmación repetida y fallo de escritura. Son rutas propuestas que se ajustarán al repositorio.

### H8 — Primera escalada científica y empresarial completa

**Entrega:** un pequeño arco que conecta negocio, investigación y construcción. Es la primera prueba de la promesa del diseño.

La implementación inicial puede conservar Lumen como producto provisional. La cadena del limpiador enzimático sigue siendo ilustrativa y no se convierte en contenido definitivo por aparecer en el diseño.

- [ ] Mantener un producto conocido rentable y un encargo básico repetible.
- [ ] Introducir un cliente identificable con una necesidad nueva, presentada inicialmente desde el terminal.
- [ ] Crear una investigación corta: comparar dos opciones frente a una referencia, interpretar un resultado y guardar la evidencia.
- [ ] Limitar la actividad a pocas variables visibles y distinguir pista, resultado y capacidad desbloqueada. No sustituir investigar por esperar una barra.
- [ ] Ofrecer un equipo de análisis nuevo cuyo precio se pueda financiar con el negocio base; permitir previsualizar su espacio antes de comprar.
- [ ] Comprar, colocar y utilizar el equipo para medir una propiedad antes inaccesible, resolver la necesidad y abrir un pedido diferente.
- [ ] Mantener la receta anterior útil y mostrar una siguiente meta concreta al terminar.

**Secuencia jugable propuesta:** encargo básico → petición especial → comparación sencilla → identificar una limitación de medición → comprar e instalar equipo → obtener una evidencia nueva → desbloquear una variante → cumplir el encargo especial.

La pregunta y la propiedad científica se elegirán al preparar esta tarea y se revisarán antes de escribir afirmaciones educativas. Las etiquetas ficticias de Lumen no prueban una base científica. El contenido abstrae procedimientos; no contiene protocolos experimentales reales.

**Reglas:** investigar consume recursos y tiempo de juego en cantidades legibles; repetir una evidencia idéntica no genera conocimiento infinito. Un intento fallido explica qué se aprendió o qué debe cambiar. Pedidos básicos permanecen accesibles y no caducan durante este primer arco. No bloquear ingresos ni el único equipo necesario para recuperarse.

**Salida:** el jugador entiende la necesidad, mantiene el negocio mientras avanza, toma una decisión en la investigación y utiliza una capacidad distinta después de comprar. Puede identificar una siguiente meta. Una reducción de tiempo de lote por sí sola no cierra H8.

**Verificación:** probar finalización y recarga en cada transición, recompensa única, comparación repetida sin explotación, fondos bajos y continuidad de los pedidos anteriores. Observar una partida humana completa antes de multiplicar recetas.

### H9 — Pueblo pequeño y clientes recurrentes

**Entrega:** salir del laboratorio y recorrer un entorno pequeño que da contexto al negocio.

- [ ] Construir con el kit exterior una calle o plaza, entrada al laboratorio y dos puntos de interés funcionales.
- [ ] Añadir dos clientes recurrentes con necesidad, diálogo breve y reacción al resultado de un encargo.
- [ ] Conectar exterior/interior con puntos de aparición seguros y conservar estado al cambiar de escena.
- [ ] Mantener trabajos en curso mientras el jugador está fuera; evitar doble cobro o reinicio al regresar.
- [ ] Introducir una relación sencilla que afecte a un encargo, precio u oportunidad visible.
- [ ] Añadir un detalle de humor negro y una pista opcional de extrañeza, sin exigir seguir el misterio para progresar.

**Salida:** el jugador sale, encuentra un motivo para hablar con alguien, vuelve y aplica lo aprendido al negocio. Un encargo puede aportar dinero, conocimiento y relación. El pueblo tiene utilidad además de ser un pasillo decorativo.

**Fuera de alcance:** ciudad completa, calendario anual, estaciones, romance, agricultura, horarios complejos y simulación de todos los habitantes. Lavandería, alimentación y taller son candidatos narrativos, no personajes ya aprobados.

### H10 — Ampliar y especializar el laboratorio

**Entrega:** primera ampliación visible con una utilidad productiva o científica concreta.

- [ ] Definir un módulo de habitación conectado, su coste, condición y uso esperado.
- [ ] Previsualizar terreno, paredes y puerta resultantes; validar conexión y ausencia de solapes.
- [ ] Comprar la ampliación como transacción única e incorporarla al guardado.
- [ ] Instalar dos equipos cuyos usos justifican separar espacios o distribuir el trabajo.
- [ ] Ofrecer una elección inicial: invertir en capacidad de producción o en capacidad de análisis, conservando una vía viable en ambos casos.
- [ ] Revisar recorridos, oclusión y recuperación de partidas con la nueva geometría.

**Salida:** ampliar cambia lo que se puede organizar o hacer; no es únicamente más suelo vacío. Se puede guardar y cargar con equipos en ambas habitaciones y regresar al laboratorio tras visitar el pueblo.

**Límite inicial:** un solo piso, módulos definidos y una especialización sencilla. Sin penalizaciones abstractas por «sala incorrecta» que el jugador no pueda prever.

### H11 — Pequeña empresa: delegar trabajo dominado

**Entrega:** un empleado realiza una única tarea ya conocida y libera tiempo para investigar o atender el pueblo.

- [ ] Elegir una tarea repetitiva validada en H8–H10, definir salario/coste y condiciones de asignación.
- [ ] Asignar empleado y estación; mostrar estado y motivo de espera.
- [ ] Coordinar acceso para que personaje y empleado no consuman ni recojan el mismo lote dos veces.
- [ ] Si falta material, acceso o dinero, detener la tarea con aviso y permitir recuperación manual.
- [ ] Guardar asignación y progreso; comprobar ausencia de trabajo duplicado tras recargar.

**Salida:** el jugador entiende qué delegó, su coste y qué actividad nueva puede hacer con el tiempo liberado. Si se representa un empleado caminando, su navegación debe soportar cambios de distribución; no simular un trabajo físicamente imposible detrás de una pared.

**Fuera de alcance:** departamentos completos, docenas de trabajadores o un sistema laboral detallado.

### H12 — Centro biotecnológico: conectar procesos

**Entrega:** una cadena corta que enlaza dos procesos y conserva el valor de un producto anterior.

- [ ] Elegir una especialidad inicial entre las candidatas industrial, ambiental o salud según el contenido validado.
- [ ] Introducir un intermedio que se puede comprar o producir y que alimenta un producto ya conocido.
- [ ] Mostrar existencias, capacidades, costes y cuello de botella sin exigir cálculos externos.
- [ ] Añadir una investigación de escalado con una decisión entre rendimiento, calidad o recursos, científicamente revisada.
- [ ] Probar falta de insumos, acumulación de producto, pausa de estación y recuperación económica.

**Salida:** comprar o producir internamente son decisiones comprensibles; aumentar volumen no elimina por defecto al proveedor ni vuelve inútil todo el contenido inicial. El siguiente escalón cambia la organización, además de aumentar cifras.

### H13 — Corporación y consecuencias regionales

**Entrega:** una segunda instalación o un gran proyecto que reutiliza los sistemas anteriores y modifica oportunidades regionales.

- [ ] Introducir una única nueva ubicación con propósito distinto y acceso mediante desplazamiento sencillo.
- [ ] Definir qué recursos se comparten y cuáles pertenecen a cada sede; mostrar transferencias explícitas.
- [ ] Añadir un contrato grande o financiación con condiciones visibles antes de aceptar.
- [ ] Representar una consecuencia sobre un cliente, un espacio o una relación del pueblo.
- [ ] Mantener una estrategia responsable viable y conservar rastros de los primeros productos y personas.
- [ ] Ampliar solo tras probar que dos instalaciones aportan decisiones sin duplicar tareas tediosas.

**Salida:** el jugador puede explicar qué tipo de empresa ha construido, qué obtuvo y qué compromisos asumió. El misterio acompaña la expansión y deja rutas atractivas centradas en el negocio.

**Estado:** horizonte de diseño, no compromiso de número de sedes, duración de campaña o fecha de lanzamiento.

### H14 — Consolidación del alcance elegido

**Entrega:** una versión distribuible y coherente del conjunto de hitos que se decida incluir. No exige llegar a H13: una demo puede cerrarse en H8 o H10.

- [ ] Revisar el recorrido completo desde partida nueva y desde partidas antiguas compatibles.
- [ ] Equilibrar ingresos, investigación y construcción para evitar bloqueos y esperas vacías.
- [ ] Completar legibilidad, sonido, controles, opciones básicas y feedback accesible sin depender del color.
- [ ] Probar exportación, licencias, continuidad, errores de guardado y carga de assets fuera del editor.
- [ ] Medir rendimiento en mapas ampliados y sesiones más largas; registrar hardware, resolución, versión y límites de la prueba.
- [ ] Ajustar contenido o alcance según juego humano; separar errores de preferencia estética.

**Salida:** se declaran funciones incluidas, límites conocidos, compatibilidad de partidas y evidencia real. Publicación comercial y distribución externa se decidirán como tareas posteriores concretas.

## 8. Verificación transversal y riesgos principales

| Riesgo | Comportamiento esperado | Hito y comprobación |
|---|---|---|
| Construcción encierra al personaje o bloquea el único equipo | Rechazar antes de aplicar; explicar el bloqueo | H7/H10: puerta, cuello de paso, giro y reubicación; recorrido físico |
| Recargar duplica un equipo, lote o pago | Identidad estable y transacción única | H7/H8: confirmar dos veces, guardar en transiciones y reabrir |
| Partida antigua pierde progreso al añadir espacio/investigación | Migración preserva saldo, inventario, lote y mejora | H7/H8: fixtures de versión previa y recuperación ante definición ausente |
| Gastar en construcción o investigar impide ganar dinero | Mantener una vía de recuperación comprensible | H8/H10: partida con fondos bajos, acceso esencial y pedidos básicos |
| Salir del laboratorio o delegar altera el tiempo o duplica trabajo | Una sola simulación y un solo propietario por trabajo | H9/H11: cambio de escena, pausa, asignación y recarga |

Pruebas automáticas para reglas con riesgo de pérdida, duplicación o bloqueo. Revisión visual para cámara, uniones, oclusión y claridad de previsualizaciones. Juego humano para comprensión, interés y sensación de crecimiento. Ninguna de esas pruebas sustituye a las otras.

Usar el ejecutable detectado. Al retomar el repositorio, comandos básicos orientativos:

```bash
godot --version
godot --headless --path . --editor --quit
godot --headless --path . --quit-after 1
```

El arranque sin ventana no valida el aspecto ni la diversión. Ejecutar las pruebas existentes afectadas; ampliar cobertura cuando aparezca un riesgo concreto. No introducir un framework solo para cambiar documentación o colocar arte estático.

## 9. Decisiones abiertas y límites de alcance

| Decisión | Cuándo resolverla | Criterio |
|---|---|---|
| Nombre del juego, pueblo y pasado del protagonista | Antes de escribir narrativa extensa | Coherencia con llegada de alguien de fuera |
| Primer producto y pregunta científica definitivos | Preparación de H8 | Relación causa–resultado clara y progresión viable |
| Tamaño exacto de celda y resolución de tiles | H6 | Personaje, tránsito, densidad de textura y coste de arte |
| Detalles de montaje con GridMap o escenas adicionales | Muestra H6 | Reimportación, colisiones y sencillez del flujo |
| Primer módulo de ampliación y precios | H10 | Uso concreto, capacidad y ausencia de bloqueo económico |
| Calendario y horarios | Después de H9 si aportan decisiones | No introducir urgencia o mantenimiento sin utilidad |
| Especialidades y profundidad empresarial | H12 | Contenido que ya ha demostrado ser divertido |
| Extensión de la corporación y distribución final | H13/H14 | Capacidad real de producción y pruebas |

No forman parte del alcance cercano: combate, terror como género principal, multijugador, cámara libre, personajes 3D animados, ciencia de simulación exhaustiva, terrenos editables libremente, edificios de varios pisos o gestión regional completa. La construcción modular limitada y el pueblo pequeño sí forman parte de este plan.

Las propuestas de programa municipal, instrumental usado, instituto antiguo y archivos contradictorios permanecen abiertas. No tratarlas como historia definitiva en diálogos, misiones o publicidad.

## 10. Correspondencia con el diseño principal

| Sección del diseño | Desarrollo previsto |
|---|---|
| 1–2. Visión y decisiones acordadas | Reglas globales; continuidad entre H8, H9 y H13 |
| 3. Producción, investigación y reinversión | Base H2/H3; primera conexión completa H8 |
| 4. Escalada y progreso visible | H7/H10 espacio; H11 delegación; H12 procesos; H13 sedes |
| 5. Ciencia y ejecución arcade | Pregunta y evidencias H8; escalado H12; pruebas humanas H5/H8 |
| 6. Pueblo, relaciones y tono | H9; consecuencias y ruta responsable H13 |
| 7. Decisiones empresariales | H8 prioridades; H10 inversión; H12 comprar/producir; H13 financiación |
| 8. Ejemplo enzimático | Referencia opcional para H8/H12, sin fijarlo como producto inicial |
| 9. Primer tramo que conviene probar | H8, apoyado por tilesets H6 y construcción H7 |
| 10. Propuestas abiertas | Sección 9 de este plan; selección cuando el hito lo requiera |
| 11. Documentación y estado real | Secciones 2 y 11; archivo histórico íntegro |
| Petición adicional: tilesets y construcción modular | Secciones 4–6; hitos H6, H7 y H10 |

## 11. Documentación, registro y siguiente acción

### Sincronización necesaria al retomar el repositorio

Esta entrega modifica únicamente `DEVELOPMENT_PLAN(2).md`. Los documentos adjuntos `AGENTS(1).md` y `Readme(1).me` siguen describiendo una fase anterior y deben sincronizarse en una tarea documental posterior:

- Reconocer la visión de laboratorio a corporación y el tono ya acordado.
- Actualizar la implementación registrada de producción, mejora, guardado y exportación.
- Sustituir el mandato antiguo de iniciar la migración 3D por continuidad desde la base existente.
- Conservar ocho direcciones y personaje aprobado.
- Incluir autoría con tilesets y construcción modular limitada sin tratarlas como un city-builder completo.
- Mantener verificaciones humanas pendientes y distinguir planificación de ejecución.

Las instrucciones actuales del usuario y el diseño aportado prevalecen frente a descripciones antiguas de alcance. Los cuidados sobre datos, atribuciones, trabajo ajeno y verificación continúan siendo aplicables.

### Registro de cada tarea

Anotar fecha, hito, objetivo observable, estado, archivos realmente modificados, decisiones, comprobaciones ejecutadas, resultado, limitaciones y siguiente acción pequeña. Estados: pendiente, en curso, bloqueado, implementado, verificado técnicamente y validado mediante juego humano. Un hito puede estar implementado sin haber superado su criterio de experiencia.

### Próxima tarea de desarrollo recomendada

Inspeccionar la base y recoger el recorrido humano de H5. La primera tarea nueva de escenarios será **H6: sustituir el suelo del laboratorio por un tileset mínimo**, conservando terminal, máquina, personaje y economía. Después validar paredes, preparar colocación de una mesa en H7 y abordar el arco de capacidad nueva de H8.

No ejecutar automáticamente trabajadores, pueblo completo o varias instalaciones. Para cada hito nuevo, concretar la siguiente tarea sobre el repositorio real y entregar algo que se pueda abrir, jugar y comprobar.

## 12. Registro de esta revisión documental — 19 de septiembre de 2026

- Reescrito el plan a partir del diseño completo facilitado por el usuario.
- Incorporados tilesets compatibles con la representación 3D existente y construcción modular escalonada.
- Definidos hitos de investigación, pueblo, ampliación, delegación, cadenas de producción y corporación.
- Actualizado el resumen con la exportación y pruebas registradas el 17 de septiembre.
- Conservado íntegro el historial previo desde la primera sala 3D, incluido el archivo de la base 2D.
- No se ha implementado ningún hito nuevo ni se han ejecutado pruebas del juego en esta revisión.

---

# Archivo histórico de implementación — contenido original conservado

Las entradas siguientes se conservan como evidencia de lo que se documentó en cada fecha, con su redacción y orden originales. Pueden contener pendientes después resueltos y recomendaciones después sustituidas. No son instrucciones actuales de ejecución: prevalecen el estado y la secuencia de las secciones anteriores. Los resultados de estas sesiones no se han vuelto a verificar durante la reescritura.

## Sesión del 15 de septiembre de 2026 — primera sala 3D

**Objetivo observable:** F5 abre una habitación 3D, permite recorrerla y consultar el terminal cercano con E.

- H1.1 implementado: inspección de Git, versión y recursos; copia previa en `.local/backups/pre-h1-3d-2026-09-15.zip`; originales 2D conservados sin desarrollar una segunda variante activa. Git carece de commits, por lo que no existe aún recuperación mediante historial versionado. Comparados 116 archivos originales contra el ZIP: sin cambios; la configuración de arranque y los dos documentos de estado son los cambios intencionados sobre archivos previos.
- H1.2–H1.4 implementados para esta primera muestra: sala de 10×10, cámara ortográfica a 55° alineada, personaje con física 3D y sprites en cuatro direcciones, mesa/ordenador, máquina y terminal con proximidad y línea de visión. UI con bloqueo y recuperación de control.
- Reutilizados los PNG y `player_frames.tres`, las acciones de entrada y el contenido/flujo del panel. Nueva escena de UI para 640×360. Assets, atribuciones y fuentes Aseprite originales conservados.
- Importación y arranque de la nueva escena principal en Godot `4.6.2.stable.official.71f334935`: sin errores. Primera ejecución restringida tuvo avisos de certificados/ajustes del editor; ejecuciones con permisos normales limpias.
- `tests/test_laboratory_3d.gd`: **38 comprobaciones, 0 fallos**. Movimiento relativo a cámara, diagonal normalizada, reposo/orientación, suelo y cuatro paredes, mesa por cuatro lados, máquina, terminal lejano/cercano/obstruido, E repetida, bloqueo con UI, Escape, clic de cierre y recuperación.
- Prueba inicial antes de implementar: falla por ausencia de sala 3D. Revisión independiente detectó una aserción débil de reposo al empujar paredes; corregida para mantener pulsada la entrada durante la comprobación, y vuelta a ejecutar satisfactoriamente.
- Capturas reales en OpenGL Compatibility con RTX 5070 Ti: sala, cuatro lados de la mesa, cuatro bordes y panel revisados. Se corrigió recorte de pared trasera por el HUD y exceso de iluminación. No se ha medido rendimiento ni estabilidad temporal con una grabación.
- Ventanas de 960×720, 1440×900 y 640×360: viewport 640×360 conservado; transformaciones uniformes ×1/×2/×1, márgenes calculados por el motor de (160,180)/(80,90)/(0,0). Capturas del viewport conservan la UI sin deformación. Las barras exteriores no están incluidas en esas capturas.
- Ficha: `docs/decisions/002-sala-3d.md`. Capturas conservadas: `docs/captures/`; registros y lote completo: `.local/`. Escenas nuevas: `laboratory_3d`, `room_shell`, `player_3d`, `terminal_3d`, `machine`, `lab_hud_3d`. Configuración activa actualizada en `project.godot`.

**Pendiente:** recorrido manual completo, aceptación visual, revisión de barras exteriores y parpadeo durante movimiento, H1.5 (modelado, UV, GLB y reimportación) y cierre de la ficha H1.6. No se ha exportado ni se ha implementado economía. Los parámetros registrados son los de la muestra revisada por capturas, sujetos a valoración del usuario.

**Siguiente acción pequeña:** probar esta habitación y elegir un único mueble para sustituir su geometría provisional mediante Blender.

## Ajuste posterior del personaje — 15 de septiembre de 2026

- Petición: mantener el personaje tal como aparece en `16x32 All Animations-Sheet.png`.
- Comprobado: los 40 fotogramas integrados de reposo/caminar son idénticos a sus equivalentes en la hoja completa. Dibujos y colores originales conservados.
- Ajustado `scenes/player/player_3d.tscn`: 0,0375 unidades/píxel y compensación vertical 1/cos(55°), para píxeles cuadrados 1:1 en el viewport. El personaje queda más pequeño que en la primera muestra y recupera su proporción original.
- Revisadas capturas reales de sala y personaje delante/detrás de la mesa. Suite 3D ejecutada de nuevo: 38 comprobaciones, 0 fallos. Sin modificar física, controles ni animaciones. Este ajuste no cierra H1.

## Ocho direcciones con sprites originales — 15 de septiembre de 2026

- Petición actual: activar ocho direcciones sin cambiar el sprite. Sustituye el alcance inicial de cuatro orientaciones de H1.3.
- `player_3d.gd` selecciona las animaciones originales `up_side`/`down_side` cuando se pulsan dos ejes; conserva orientación al detenerse y refleja las vistas izquierdas igual que en la base anterior.
- PNG, `player_frames.tres`, escala, paleta y configuración visual del personaje intactos.
- Suite ampliada: las ocho comprobaciones de caminar/reposo diagonal fallaban antes del cambio. Después: **46 comprobaciones, 0 fallos**, incluyendo velocidad diagonal, colisiones y UI.
- `capture_laboratory_3d.gd` también captura las cuatro diagonales caminando y en reposo. No se añaden otras mecánicas ni se cierra H1.

## Retirada del prototipo 2D — 15 de septiembre de 2026

- Petición: eliminar objetos y escenas que ya no se usan, tras revisar la lista.
- Comprobado antes de borrar: la cadena 3D activa (`laboratory_3d`, `room_shell`, `player_3d`, `terminal_3d`, `machine`, `lab_hud_3d`) no referencia ninguna escena, script ni recurso 2D. Los tres scripts 3D no tienen `preload`, `load()` ni `extends` hacia la base anterior.
- Borrados (18 archivos, contando `.uid`): `scenes/world/laboratory.tscn|.gd`, `scenes/player/player.tscn|.gd`, `scenes/lab/terminal.tscn|.gd`, `scenes/ui/lab_hud.tscn`, y las pruebas que cargaban `laboratory.tscn`: `test_laboratory.gd`, `test_player_animation.gd`, `capture_preview.gd`, `capture_terminal.gd`.
- Conservados por seguir en uso o por mandato de AGENTS.md: `player_frames.tres` y `assets/game/player/` (los usa `player_3d.tscn`), `capture_player_animation.gd` (solo carga el `SpriteFrames`), los PNG de PC/escritorio como referencia para H1.5, y todas las fuentes originales y Aseprite.
- Verificado tras el borrado: sin referencias colgando en el proyecto; `--editor --quit` importa sin errores en `4.6.2.stable.official.71f334935`; `tests/test_laboratory_3d.gd` da **46 comprobaciones, 0 fallos**, el mismo resultado que antes de borrar.
- Limitación: la rama sigue sin commits, por lo que la única recuperación de la base 2D es `.local/backups/pre-h1-3d-2026-09-15.zip`, verificado como contenedor de los 18 archivos. Queda pendiente el commit inicial que pide AGENTS.md.
- No se han borrado los duplicados exactos ni el `.import` huérfano identificados (`assets/pc-original - copia.png`, `assets/expressions/animation-screen-pc.png.import`). H1 sigue en curso; este borrado no cierra ningún hito.

## Cartel de interacción sobre el objeto — 15 de septiembre de 2026

- Petición: al acercarse a un objeto que se puede usar, que aparezca algo encima de él.
- Nueva escena reutilizable `scenes/ui/interact_hint.tscn` + `interact_hint.gd` (`class_name InteractHint`): un `Label3D` en billboard con `pixel_size` 0,0375, es decir 1 píxel de textura = 1 píxel del viewport de 640×360, igual que el personaje. Aparece subiendo con un fundido corto y flota despacio; no conoce al jugador ni contiene reglas de juego.
- `terminal_3d.tscn` la instancia a 2,26 de altura sobre la mesa con el texto «E · Consultar»; `terminal_3d.gd` expone `set_hint_active()` y `laboratory_3d.gd` la activa solo cuando `can_interact()` es cierto, de modo que se retira al alejarse, tras una pared y mientras el panel está abierto. El aviso de la barra inferior se conserva.
- La máquina sigue sin ser interactuable, así que no lleva cartel. Sin cambios en movimiento, colisiones, cámara, luces ni animaciones.
- `tests/test_laboratory_3d.gd`: **56 comprobaciones, 0 fallos** (46 antes). Las diez nuevas cubren lejos/cerca, altura sobre el objeto, posición en pantalla por encima del monitor, panel abierto, pared entre medias y alejarse. Se añadió `_await_until()` porque el fundido depende del tiempo real.
- Capturas reales regeneradas con `tests/capture_laboratory_3d.gd`; se conserva `docs/captures/h1-3d-interact-hint.png`. El encuadre y la iluminación coinciden con `h1-3d-desk-front.png`: el cartel es el único cambio visible.
- Incidencia corregida: al ejecutar `.local/build_h1_scenes.py` se reescribieron las cuatro escenas que genera, devolviendo la cámara y las luces a valores anteriores al ajuste manual. Restaurados (`size` 13,5, cámara en y 13,34, ambiente 0,4, luz 0,55) y el generador actualizado; ahora reproduce las escenas actuales byte a byte, verificado con `diff`. `room_shell.tscn` y `machine.tscn` no tenían diferencias.
- Limitación: revisión visual hecha sobre capturas, sin recorrido manual del usuario. Esto no cierra H1.

## H1.5 — Primer terminal pixel art — 16 de septiembre de 2026

- Petición: continuar con arte pixel art y mantener el personaje aprobado sin cambios.
- Sustituida la geometría provisional visible del terminal por `assets/game/models/terminal.glb`, creado en Blender 5.2.1 con UV y atlas 128×128. Mesa gris azulada, cajones, PC marfil, pantalla verde, teclado y cuaderno.
- Fuentes editables y flujo reproducible en `assets/source/terminal/`; material nearest sin iluminación y sin mipmaps de muestreo en `assets/game/materials/terminal_pixel.tres`. Sin nuevos plugins ni cambios de motor.
- Conservados el área, colisión, punto de interacción, scripts y el indicador flotante que ya estaba en el proyecto al retomar. Los 33 archivos comprobados del personaje permanecen idénticos.
- Importación y reexportación verificadas: se amplió el piloto del monitor en Blender; el GLB cambió sin alterar la escena contenedora ni perder interacción. La configuración nativa de material externo persiste.
- Suite de la base actual, incluidas las pruebas del indicador: **56 comprobaciones, 0 fallos** antes y después de importar/reexportar. Capturas de sala y cuatro lados del mueble revisadas. El flujo de actualización explícita del atlas también se ejecutó.
- Ficha y evidencia: `docs/decisions/003-terminal-pixel-art.md`; instrucciones de autoría: `assets/source/terminal/README.md`; capturas finales en `docs/captures/h1-5-*.png`.
- H1.5: flujo técnico comprobado, valoración artística pendiente. H1 sigue en curso: falta recorrido manual completo, revisión de estabilidad visual y aceptación de la muestra H1.6. Resto del mobiliario provisional. No se ha exportado el juego ni ampliado la economía.

## Paleta clara e iluminación alegre — 16 de septiembre de 2026

- Petición: aclarar suelo y paredes y dar al laboratorio colores más alegres, conservando el personaje aprobado.
- Implementado: baldosas blancas frías con juntas azuladas, paredes claras, remates turquesa, mobiliario provisional azul cielo y pequeños acentos coral/amarillo. Fondo azul e interfaz clara con texto oscuro.
- Luz directa neutra con energía 0,16 y ambiente 0,45. Se redujo la luz directa tras comprobar en una primera captura que los blancos perdían detalle. Cámara, geometría, colisiones y terminal GLB conservados.
- Verificado en Godot 4.6.2: importación y render sin errores; **56 comprobaciones, 0 fallos**. Comparados los hashes de los 33 archivos del personaje y sus fuentes: ninguno cambió. Capturas de sala y panel revisadas, guardadas en `docs/captures/h1-bright-room.png` y `h1-bright-panel.png`.
- H1 continúa abierto; esta revisión de capturas no acredita una sesión manual completa ni estabilidad temporal durante movimiento. La nueva paleta queda pendiente de valoración del usuario.

## Primer pedido completo — 16 de septiembre de 2026

- Nueva dirección del usuario: juego de rutinas de laboratorio corporativo, inspirado en Stardew Valley y una corporación tipo Umbrella. Desarrollar mecánicas y bases, dejando la evolución del arte al usuario.
- Implementado H2: ordenador con compras, entrega y nueva orden; máquina con preparación y recogida; almacén, saldo entero, contador de encargos y lote temporizado de 12 segundos. Se puede caminar y reponer material mientras produce. Escape desde la sala pausa movimiento y producción.
- Balance inicial editable: 120 cr; matriz 12 + catalizador 8; una muestra Lumen por lote; encargo paga 35. Tres ciclos comprobados con 135, 150 y 165 cr. Lumen y su receta son ficticios.
- Revisión de jugabilidad: devolver existencias sin usar permite recuperarse de gastar todo el saldo en un solo ingrediente. Nunca reintegra lo consumido por un lote. Entregas con ID, solicitud explícita del siguiente pedido y rechazos sin mutación parcial.
- Arquitectura: `LabDefinitions` Resource y `LabSession` local a la sala, independientes de UI y representación. Sin plugins, autoloads ni modificaciones al personaje/arte. Área frontal de interacción en la máquina reutiliza la comprobación de obstáculos.
- Godot 4.6.2: **133 comprobaciones de dominio + 27 del recorrido real + 56 anteriores = 216, cero fallos**. Incluyen pausa, movimiento durante producción, falta de saldo/material, doble recogida/entrega, recuperación mediante devoluciones, datos de balance inválidos e independencia de sesiones. Revisión independiente completada; sus tres hallazgos fueron corregidos y revisados de nuevo.
- Capturas con renderer real de terminal, máquina produciendo/lista, pausa y entrega, a 640×360 interno; también ventana 960×720. Fuentes y personaje comparados mediante SHA256 con el estado previo.
- H2: primer ciclo comprobado. Pendiente valorar con juego manual si la rutina resulta entretenida; esta base aún tiene una sola receta y pedido. H3 pendiente: mejora y guardado. El juego avisa en pausa de que la sesión se pierde al cerrar. No se ha exportado ni cerrado la revisión manual de H1.
- Decisión/contrato: `docs/decisions/004-primer-pedido.md`. Pruebas: `tests/test_lab_session.gd`, `tests/test_order_loop.gd`, `tests/test_laboratory_3d.gd`; capturas reproducibles con `tests/capture_order_loop.gd`.

## Mejora y progreso persistente — 16 de septiembre de 2026

- H3 implementado: calibración de precisión por 100 cr, desbloqueada tras tres pedidos. Reduce de 12 a 8 s los lotes nuevos. Rechaza compra duplicada, falta de saldo y máquina ocupada. Tras tres pedidos y la mejora quedan 65 cr para continuar.
- Snapshot versionado con saldo, inventario, encargos, mejora, estado/duración/tiempo restante del lote. Validación completa antes de aplicar; sin avance offline. Posición del personaje vuelve al inicio seguro al cargar.
- Persistencia local a la sala en `user://lab_save.json`: guarda transacciones, lote listo, progreso cada cinco segundos, pausa y cierre normal. Escritura temporal verificada, copia válida y recuperación explícita. Nueva partida confirmada archiva archivos previos. Fallo de escritura pausa, conserva la última partida y permite reintentar sin perder el estado en memoria.
- Corrección detectada durante la revisión: archivos `.recovering`, `.replacing` o `.tmp` sin primaria no pueden tratarse como instalación vacía. Ahora se ofrecen para recuperación explícita si son válidos; no se pisan con una partida inicial.
- **335 comprobaciones, cero fallos:** 133 dominio H2, 27 recorrido H2, 56 laboratorio, 51 mejora/snapshot, 48 almacén, 15 partida completa y 5 fallo/reintento/cierre de ventana. El recorrido prueba también el autoguardado periódico en tiempo real. Todos usan rutas aisladas; no escriben sobre la partida del usuario.
- Render OpenGL real de mejora bloqueada/disponible/comprada, lote mejorado, pausa, nueva partida y recuperación. Capturas seleccionadas `docs/captures/h3-*.png`. Los 33 archivos del personaje/fuentes conservan sus SHA256.
- El almacén fue implementado por un agente y revisado/corregido localmente al integrar. La revisión independiente final no pudo completarse por límite de uso de esa herramienta; no se presenta como realizada. Pruebas y revisión local sí ejecutadas.
- No se ha realizado exportación ni sesión manual larga. H4 queda pendiente; el objetivo general continúa activo. Contrato y detalles: `docs/decisions/005-progreso-y-guardado.md`.

## Avisos y claridad del laboratorio — 16 de septiembre de 2026

- H4 en curso: sonidos originales cortos para operaciones, cobro, mejora y lote listo. Avisos escritos acompañan el sonido, permanecen al cerrar el panel y se ocultan mientras hay menús; no bloquean entradas. La transición a listo se anuncia una vez y cargar un lote ya listo no simula otra finalización.
- Control de sonido en pausa, persistido en `audio.cfg` junto a la partida. Mantiene `schema_version = 1` intacto. Guía mejorada: ingrediente concreto que falta, recuperación mediante devolución y recomendación de mejora solo si se puede pagar.
- 14 comprobaciones nuevas aprobadas; recorrido de pedidos 27, carga/recuperación 15, fallo/reintento/cierre 5 y laboratorio 56 revalidados sin fallos: 117 de integración en esta entrega. Revisión de capturas real a 640×360, incluido el menú con error de guardado. Muestras de audio PCM16 verificadas sin saturación; valoración acústica del usuario pendiente.
- Personaje/fuentes: 33 hashes intactos. No se cambia arte, economía ni partidas. Un aviso de ObjectDB en un primer cierre headless no se reprodujo con verbose; se registra sin atribuirle una causa no demostrada.
- Contrato y detalles: `docs/decisions/006-avisos-laboratorio.md`. Capturas reproducibles mediante `tests/capture_lab_feedback.gd`. Exportación y validación manual siguen pendientes.

## Historial conservado — prototipo 2D anterior


Las entradas siguientes se mantienen como registro de los documentos recibidos. Sus nodos 2D, escalas, estados, resultados y «siguientes acciones» corresponden al 8 de septiembre. No se han vuelto a verificar y no sustituyen el plan actual de migración.

## Sesión del 8 de septiembre de 2026 — base inicial

- H0: ficha en `docs/decisions/001-prototipo.md` con alternativas y primeros cinco minutos previstos. El usuario eligió personaje cenital y gestión desde equipos. PC, estilo y cámara definitiva siguen abiertos.
- H1 en curso: proyecto Godot 4.6.2, sala recorrible, colisiones, cámara, terminal cercano y panel que bloquea el movimiento. Escenas separadas para mundo, personaje, terminal y UI; sin autoloads ni plugins.
- Verificado: versión real, importación del editor sin errores y ocho comprobaciones automatizadas de movimiento/interacción, con cero fallos. Escena renderizada mediante OpenGL; capturas revisadas. Corregido el margen superior de cámara al detectar oclusión por el HUD.
- Entorno: primera ejecución restringida produjo avisos de certificados/permisos; la repetición con permisos normales pasó limpia. El log relativo causó un fallo del motor; las ejecuciones posteriores usaron ruta absoluta.
- Git inicializado sin commits. `Readme.me` creado porque no existía al inicio; no se ha reconstruido un original desconocido.
- Pendiente para cerrar H1: recorrer manualmente todos los bordes, comprobar cámara, botón y redimensionado. No se ha exportado ni probado H2.
- Siguiente acción pequeña: revisión manual de esta sala; después implementar una sola compra de insumos con saldo validado como inicio de H2.

## Integración de sprites 16×32 — 8 de septiembre de 2026

- Solicitud del usuario: añadir al personaje los sprites de `assets/16x32/`.
- Implementado: `AnimatedSprite2D` sustituye las formas del personaje; reposo y caminar en ocho orientaciones, conservando dirección al detenerse. Cuatro fotogramas a 10 FPS por cada una de las cinco vistas fuente; reflejo horizontal para las vistas izquierdas. Escala visual ×2, filtrado nearest y pivote en los pies. Colisión, velocidad y controles conservados.
- Fuentes PNG y Aseprite originales conservadas. Dos copias exactas integradas en `assets/game/player/`, con atribución y condiciones enlazadas. Los lienzos son de 32×32, según el Read Me del paquete y los metadatos Aseprite.
- Verificado con Godot 4.6.2: importación sin errores, 28 comprobaciones de animación y 8 de movimiento/terminal, cero fallos. Capturas renderizadas del personaje en la sala y en los bordes norte/sur revisadas.
- H1 permanece en curso. No se ha exportado ni realizado una sesión manual completa; no se añaden mecánicas de salto, carrera o ataque por existir esas hojas en el paquete.

## PC y escritorio — 8 de septiembre de 2026

- Solicitud del usuario: integrar `assets/pc-original.png` y `assets/desktop.png`.
- Implementado: dos Sprite2D sustituyen las formas del terminal; PC colocado sobre el tablero. Escala nativa ×1, nearest, transparencia original y coordenadas enteras. Copias binarias exactas en `assets/game/terminal/`; originales conservados.
- Ajustada la huella de colisión a 96×32, con origen a los pies. El conjunto se desplaza 48 píxeles hacia abajo en la sala para dejar margen bajo el HUD. El rótulo permanece encima del PC; E y el panel mantienen su funcionamiento.
- Verificado: once comprobaciones del laboratorio aprobadas, incluyendo colisión frontal y ambos laterales. Las dos pruebas laterales fallaron con el antiguo collider y pasan con el del escritorio. Capturas de la sala, del panel y del personaje delante, detrás y al lado revisadas en Godot 4.6.2.
- H1 continúa en curso: esta tarea no acredita una sesión manual completa ni una exportación. No se incorporan otros sistemas.

## Ajuste de proporciones — 8 de septiembre de 2026

- Petición del usuario: reducir la escala de objetos y personaje. Personaje de ×2 a ×1,5; escritorio de ×1 a ×0,5; PC de ×1 a ×0,375. El conjunto pasa de 109 a 46 píxeles de alto y el personaje visible de unos 48 a 36.
- Ajustados pivotes y sombra, colisión del personaje a 14×10, huella del escritorio a 48×16 y radio de interacción a 40. Cámara, velocidad y PNG originales conservados.
- Revisadas capturas de la sala y del personaje delante, detrás y al lado del escritorio. Once comprobaciones del laboratorio aprobadas, incluyendo el límite máximo de separación para detectar colisiones invisibles demasiado grandes.
- La muestra visual usa escalas fraccionarias con nearest. Es una proporción provisional; el ajuste no equivale a cerrar H1 ni a validar una exportación.

## Sesión del 17 de septiembre de 2026 — exportación Windows

H4: versión local x86_64 en `builds/windows/Biotech.exe` y `Biotech.pck`, instrucciones y licencias. Preset y script de reconstrucción verificados con Godot 4.6.2. Corregidas dependencias que faltaban en el primer paquete.

Verificados directamente en el EXE el arranque, creación de partida, autoguardado durante producción, continuación en otro proceso y render de la sala. Perfil de APPDATA aislado; partida real intacta. Arnés externo sobre el PCK: 32 comprobaciones sin fallos, con ciclo/mejora/recarga. El cierre headless del arnés conserva un aviso de objetos de audio pendientes de liberar; no se presenta como resuelto. Personaje: 33 archivos sin cambios.

Ficha y reproducción: `docs/decisions/007-exportacion-windows.md`. H4 sigue en curso: faltan prueba humana sin instrucciones verbales y sesión prolongada/rendimiento. No se añade contenido de H5/H6 por rutina.

## Sesión del 17 de septiembre de 2026 — cierre de pruebas de audio

Diagnóstico del aviso de ObjectDB de la exportación: un caso mínimo confirma que detener un sonido no libera inmediatamente la reproducción del servidor de audio. El arnés cerraba el proceso antes de esa liberación; esperando se observan cero recursos retenidos. Corregido solo `tests/test_exported_lab.gd`: conserva referencias débiles y comprueba su liberación con un límite de un segundo tras retirar la sala.

Verificación sobre el PCK existente en tres procesos headless: 33 comprobaciones (14/11/8), cero fallos y sin avisos de audio retenido. Logs `.local/audio-debug/`. EXE y PCK conservan sus hashes. No se modifica el juego ni se añade un retraso a su cierre. El recorrido humano y la valoración de diversión siguen pendientes; solicitada experiencia del usuario mediante una pregunta breve.

## Sesión del 17 de septiembre de 2026 — continuidad y rendimiento

H4: escenario técnico automatizado sobre el PCK, sin cambios al juego. Sesión gráfica de 186,58 segundos con tiempos reales, movimiento, paneles, pausa y autoguardado: 20 pedidos, mejora y saldo de 320 cr; cero fallos, errores o avisos. Ventana 1280×720, interna 640×360, Ryzen 7 9800X3D / RTX 5070 Ti / OpenGL Compatibility, límite 60 FPS y VSync. 11.195 intervalos: mediana 16,666 ms, p99 16,776 ms, máximo 18,098 ms.

Ficha y datos: `docs/decisions/008-sesion-y-rendimiento.md`. El arnés no valida desplazamiento humano entre estaciones ni rendimiento máximo; tres minutos no sustituyen sesiones de horas. Añadida `docs/PRUEBA_JUGABLE.md` con registro sin completar para la comprensión del recorrido. H4 sigue pendiente de evidencia humana; no se amplía H5/H6 por rutina. La pregunta enviada al usuario sobre completar tres pedidos y comprar la mejora sigue sin respuesta.
