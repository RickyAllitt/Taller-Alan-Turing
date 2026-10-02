# DevSecOps & Container DFIR: Supply Chain Attacks, Breakouts & Hardening

Taller interactivo y escenario de laboratorio para **Killercoda** diseñado para los alumnos del **Curso de Especialización en Ciberseguridad** del **CPIFP Alan Turing (Málaga)**.

---

## 📌 Contexto del Proyecto

Este escenario sumerge a los estudiantes en un entorno práctico de 75 minutos enfocado en seguridad de contenedores, respuesta a incidentes (DFIR) y prácticas DevSecOps:

1. **Reconstrucción ofensiva y extracción de credenciales**: Análisis de ataques a la cadena de suministro (*Poisoned Pipeline Execution*) e inspección forense de memoria de procesos (`/proc/1/environ`).
2. **Escape de contenedor**: Explotación de sockets UNIX de Docker expuestos (`/var/run/docker.sock`) para obtener control de root sobre el host físico.
3. **Triaje DFIR y Threat Hunting**: Análisis de capas de OverlayFS (`upperdir`) y desarrollo de reglas YARA para la detección de implantes maliciosos y canales C2.
4. **Hardening y DevSecOps**: Refactorización de despliegues Docker Compose aplicando controles del **CIS Docker Benchmark** (sistemas de archivos de solo lectura, usuarios no-root, eliminación de capacidades y prevención de escalada de privilegios).

---

## 🏗️ Estructura del Repositorio

```text
.
├── index.json                    # Manifiesto de configuración del escenario en Killercoda
├── background.sh                 # Aprovisionamiento desatendido (Docker, YARA, jq, flags, artefactos)
├── foreground.sh                 # Banner interactivo de bienvenida y bucle de espera
├── step1/verify.sh               # Validación del Reto 1 (Extracción de credenciales de PID 1)
├── step2/verify.sh               # Validación del Reto 2 (Escape de contenedor vía docker.sock)
├── step3/verify.sh               # Validación del Reto 3 (Detección de implante con regla YARA)
├── step4/verify.sh               # Validación del Reto 4 (Auditoría de hardening con docker inspect)
└── assets/
    ├── docker-compose.yml        # Configuración vulnerable del runner de CI/CD
    ├── victim/
    │   ├── Dockerfile            # Imagen base del runner vulnerable
    │   └── pipeline_runner.sh    # Demonio del pipeline ejecutado como PID 1
    └── evidence/
        └── backdoor_implant.sh   # Implante malicioso utilizado en el triaje forense
```

---

## 🚀 Despliegue en Killercoda

1. Vincula este repositorio con tu cuenta y perfil de creador en [Killercoda](https://killercoda.com/).
2. El archivo `index.json` define automáticamente el backend con la imagen oficial de `ubuntu`, la configuración de paneles interactivos y los scripts de verificación de cada paso.
3. Al iniciar el escenario, `background.sh` aprovisionará silenciosamente el entorno mientras `foreground.sh` presenta una animación de bienvenida al estudiante hasta que el sistema esté 100% operativo.
