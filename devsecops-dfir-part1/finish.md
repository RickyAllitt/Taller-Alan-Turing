# ¡Parte 1 Completada: Fase Ofensiva Superada!

## Resumen de la Fase Ofensiva

Has completado con éxito la fase de intrusión y compromiso en la cadena de suministro basada en contenedores:
1. **Desafío 1 (200 pts):** Envenenamiento de pipeline CI/CD y recolección de credenciales en memoria de procesos (`/proc/1/environ`).
2. **Desafío 2 (250 pts):** Explotación de la arquitectura cliente-servidor de Docker y escape al sistema host mediante `/var/run/docker.sock`.

**Puntuación acumulada en la Parte 1: 450 / 450 Puntos Base.**

```text
Cadena de Ataque Reconstruida en la Parte 1
────────────────────────────────────────────────────────────────────────────────────────
Técnica Atacante (MITRE ATT&CK)        Condición Explotada          Impacto Obtenido
────────────────────────────────────────────────────────────────────────────────────────
T1195.002 (Ataque a Cadena Suministro) Espacio PID compartido       Credenciales de despliegue
                                       Secretos en memoria proceso  filtradas (DEPLOY_PRODUCTION_KEY)
────────────────────────────────────────────────────────────────────────────────────────
T1611 (Escape al Host)                 Montaje docker.sock          Toma de control de root
                                       Contexto de usuario root     en el sistema host anfitrión
────────────────────────────────────────────────────────────────────────────────────────
```

---

## Instrucciones para Continuar: Iniciar la Parte 2

La siguiente fase del taller aborda la respuesta a incidentes (**DFIR**) y la securización en producción (**DevSecOps**).

1. Abre el catálogo de escenarios de Killercoda e inicia:
   **"Parte 2: Container DFIR & Production Hardening"**
2. En la nueva terminal de la Parte 2, registra el **MISMO indicativo o nombre** que usaste aquí:
   ```bash
   score register <tu_mismo_nombre>
   ```
   *El sistema detectará automáticamente tu progreso y vinculará tus 450 puntos acumulados.*
3. Completa los dos desafíos defensivos restantes para alcanzar los **1.000 Puntos Máximos** en el marcador en vivo.

Consulta el marcador en vivo de la clase:
**https://rickyallitt.github.io/Taller-Alan-Turing**
