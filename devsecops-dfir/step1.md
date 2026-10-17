# Desafío 1: Envenenamiento de Pipeline y Extracción de Secretos en Memoria

**Tiempo Asignado: 12 - 15 minutos**

---

## Modelado de Amenazas: Exposición de Credenciales en Memoria

En la taxonomía de ataques contra pipelines de integración continua (Poisoned Pipeline Execution - MITRE ATT&CK [T1195.002](https://attack.mitre.org/techniques/T1195/002/)), un atacante que logra inyectar código no verificado o una Pull Request maliciosa en un runner puede inspeccionar el entorno de ejecución. Una deficiencia arquitectónica muy común en runners desatendidos es inyectar secretos estáticos directamente como variables de entorno en el proceso supervisor o script de entrada del contenedor.

Cuando se ejecutan tareas dentro del contenedor:
- Las sesiones secundarias (como subshells o sesiones creadas mediante `docker exec`) a menudo se inician con tablas de variables de entorno saneadas o restringidas, dando a los administradores la falsa sensación de que los secretos del proceso padre están ocultos.
- Sin embargo, el aislamiento estándar de contenedores Linux se basa en espacios de nombres (*namespaces*). Al compartir el mismo espacio de nombres de procesos (PID namespace), cualquier proceso con el mismo UID (o como root) tiene acceso de lectura al pseudosistema de ficheros `/proc` del resto de procesos.
- El kernel de Linux expone el bloque de variables de entorno con el que fue inicializado cualquier proceso a través de `/proc/[PID]/environ`.

---

## Arquitectura del Kernel: Disposición de Memoria en `/proc/[PID]/environ`

El archivo `/proc/[PID]/environ` es una interfaz virtual generada dinámicamente por el kernel de Linux a partir de los descriptores de memoria del proceso:
- El kernel lee el rango de direcciones de memoria delimitado por `mm_struct->env_start` y `mm_struct->env_end` en el espacio de direcciones del proceso objetivo.
- Formato: Según el estándar POSIX, el bloque de variables de entorno consiste en asignaciones consecutivas `CLAVE=VALOR` separadas por un byte nulo (`\x00` / ASCII 0), en lugar del salto de línea convencional (`\n`).
- Comportamiento ante flujos binarios: Las herramientas convencionales de filtrado de texto (`grep`, `tail`, `less`) interpretan los bytes nulos como terminadores de cadena o indicadores de archivo binario, lo que puede truncar la lectura o generar salidas desestructuradas.

Para transformar este volcado de memoria en registros legibles por líneas, puedes emplear utilidades estándar POSIX:
- `tr(1)`: Traduce caracteres entre bytes (por ejemplo, convirtiendo bytes nulos `\0` en saltos de línea `\n`).
- `strings(1)`: Escanea flujos de bytes binarios y extrae secuencias consecutivas de caracteres imprimibles.
- `awk(1)`: Procesa registros delimitados definiendo un separador personalizado (`RS="\0"`).

---

## Objetivos Técnicos

1. Conectarte a una shell interactiva dentro del contenedor de compilación activo: `cicd_runner_pipeline`.
2. Enumerar la tabla de procesos del contenedor para identificar la jerarquía y el PID del proceso supervisor principal.
3. Inspeccionar el mapeo de memoria virtual de variables de entorno de PID 1 bajo `/proc`.
4. Transformar el flujo delimitado por bytes nulos en líneas de texto e identificar la credencial de producción asociada a `DEPLOY_PRODUCTION_KEY`.
5. Salir del contenedor y guardar el token recuperado en `/tmp/flag1.txt` dentro de la máquina host.

---

## Guía de Ejecución

### 1. Acceso al Contenedor y Mapeo de Procesos
Accede a `cicd_runner_pipeline` mediante `docker exec`. Inspecciona los procesos en ejecución con `ps -ef` o `ps aux`. Diferencia entre los procesos transitorios de tu subshell y el proceso persistente que actúa como raíz del contenedor (PID 1).

### 2. Inspección del Flujo de Memoria del Entorno
Inspecciona `/proc/1/environ`. Comprueba que al ejecutar `env` dentro de tu subshell no se observan las credenciales sensibles, pero al leer la estructura de memoria de PID 1 se revelan los secretos inyectados en la inicialización del contenedor.

Utilizando manipulación de flujos POSIX (`tr(1)`, `strings(1)` o herramientas equivalentes), formatea la salida por líneas y filtra por el prefijo `DEPLOY_` o el formato estándar de flag `FLAG{...}`.

### 3. Extracción y Almacenamiento del Artefacto
Regresa a la terminal del sistema host (`exit`) y guarda la credencial capturada en `/tmp/flag1.txt`:

```text
Entregable: /tmp/flag1.txt
Contenido:  FLAG{...}
```

---

## Requisitos de Verificación

Asegúrate de que `/tmp/flag1.txt` existe en el host y contiene exactamente la cadena de la flag. Ejecuta el script de validación automatizada:

```bash
/step1/verify.sh
```

Al validar con éxito, se te otorgarán **200 Puntos Base** (menos las pistas que hayas consumido), que se sincronizarán inmediatamente con el marcador en vivo. Si te quedas atascado, ejecuta `hint 1` para solicitar pistas técnicas.
