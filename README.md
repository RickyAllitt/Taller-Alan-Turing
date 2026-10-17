# DevSecOps & Container DFIR: Supply Chain Attacks, Breakouts & Hardening

Taller interactivo y escenario de laboratorio para **Killercoda** diseñado para los alumnos del **Curso de Especialización en Ciberseguridad** del **CPIFP Alan Turing (Málaga)**.

Incluye un **sistema de puntuación en tiempo real**, **pistas tácticas graduadas (hint CLI)** y una **web de Leaderboard en vivo** alojada en **GitHub Pages** conectada a **Firebase Realtime Database**.

---

## 📌 Contexto del Proyecto

Este escenario sumerge a los estudiantes en un entorno práctico de 75 minutos enfocado en seguridad de contenedores, respuesta a incidentes (DFIR) y prácticas DevSecOps:

1. **Reconstrucción ofensiva y extracción de credenciales (200 pts)**: Análisis de ataques a la cadena de suministro (*Poisoned Pipeline Execution*) e inspección forense de memoria de procesos (`/proc/1/environ`).
2. **Escape de contenedor (250 pts)**: Explotación de sockets UNIX de Docker expuestos (`/var/run/docker.sock`) para obtener control de root sobre el host físico.
3. **Triaje DFIR y Threat Hunting (300 pts)**: Análisis de capas de OverlayFS (`upperdir`) y desarrollo de reglas YARA para la detección de implantes maliciosos y canales C2.
4. **Hardening y DevSecOps (250 pts)**: Refactorización de despliegues Docker Compose aplicando controles del **CIS Docker Benchmark** (sistemas de archivos de solo lectura, usuarios no-root, eliminación de capacidades y prevención de escalada de privilegios).

---

## 🎯 Sistema de Pistas y Puntuación (1.000 Puntos Totales)

- **Registro en Vivo**: Al iniciar la terminal de Killercoda, el script `foreground.sh` solicita un alias o indicativo al alumno y registra la sesión en Firebase.
- **Pistas en Terminal**: El alumno puede consultar pistas en cualquier momento mediante el comando:
  ```bash
  hint <numero_reto>
  # Ejemplo: hint 1
  ```
  Cada pista advierte del coste de puntos y solicita confirmación antes de descontarlos del reto correspondiente.
- **Telemetría Automática**: Al superar cada reto mediante `/step<N>/verify.sh`, la puntuación neta (puntos base menos penalizaciones por pistas) y la hora de finalización (hora local española con formato AM/PM) se sincronizan inmediatamente con Firebase y la tabla de clasificación pública.

---

## 🌐 Leaderboard en GitHub Pages (`/docs`)

El panel de clasificación en tiempo real se encuentra en la carpeta [`docs/`](docs/) listo para ser publicado mediante GitHub Pages:

- **URL de Producción**: [https://rickyallitt.github.io/Taller-Alan-Turing](https://rickyallitt.github.io/Taller-Alan-Turing)
- **Tecnología**: HTML5, Vanilla CSS (estética Cyberpunk/Dark Mode), Vanilla JavaScript con sincronización Server-Sent Events (SSE) hacia Firebase Realtime Database.
- **Métricas**: Ranking de alumnos, tiempos de finalización en hora española, insignias por reto, conteo de pistas consumidas y cuadro de honor "First Blood" (resolución más rápida por reto).

---

## ⚙️ Configuración de Firebase Realtime Database

1. Crea un proyecto en [Firebase Console](https://console.firebase.google.com/).
2. En la sección **Build > Realtime Database**, crea una base de datos en modo prueba o personalizada.
3. Ve a la pestaña **Rules** y pega las reglas de seguridad de [`firebase-rules.json`](firebase-rules.json):
   ```json
   {
     "rules": {
       "workshops": {
         "$workshop_id": {
           ".read": true,
           "students": {
             "$student_id": {
               ".write": true,
               ".validate": "newData.hasChildren(['alias', 'registeredAt', 'totalScore']) && newData.child('alias').isString() && newData.child('alias').val().length >= 2 && newData.child('alias').val().length <= 25 && newData.child('totalScore').isNumber() && newData.child('totalScore').val() >= 0 && newData.child('totalScore').val() <= 1000 && (!data.exists() || newData.child('alias').val() == data.child('alias').val()) && (!data.exists() || newData.child('totalScore').val() >= data.child('totalScore').val())"
             }
           }
         }
       }
     }
   }
   ```
4. La URL de la base de datos ya está configurada con la instancia activa (`https://bootcamp-ac825-default-rtdb.europe-west1.firebasedatabase.app`) en:
   - [`devsecops-dfir-part1/assets/scoring/config.env`](devsecops-dfir-part1/assets/scoring/config.env) y Part 2 (`FIREBASE_DATABASE_URL`)
   - [`docs/config.js`](docs/config.js) (`databaseURL`)
   *(O configúralo directamente desde el navegador haciendo clic en el botón "DB Settings" del Leaderboard)*.

---

## 🏗️ Estructura del Repositorio

```text
.
├── structure.json                         # Mapeo de cursos/escenarios en Killercoda
├── firebase-rules.json                    # Reglas de validación para Firebase RTDB
├── docs/                                  # Web del Leaderboard en GitHub Pages
│   ├── index.html                         # Dashboard de clasificación en tiempo real
│   ├── style.css                          # Estilos personalizados Vanilla CSS
│   ├── app.js                             # Lógica de sincronización SSE y métricas
│   └── config.js                          # Configuración de Firebase y taller
├── devsecops-dfir-part1/                  # Escenario Parte 1 (Ofensiva: Retos 1 y 2 - 35 min)
│   ├── index.json                         # Manifiesto de Killercoda Parte 1
│   ├── background.sh / foreground.sh      # Aprovisionamiento y registro de sesión
│   ├── intro.md / finish.md               # Briefing y cierre de la Parte 1
│   ├── step1.md y step2.md                # Retos 1 (Inyección CI/CD) y 2 (Escape Docker Socket)
│   ├── step1/ y step2/                    # Scripts de verificación y scoring
│   └── assets/                            # Recursos, scoring client y pistas
└── devsecops-dfir-part2/                  # Escenario Parte 2 (Defensiva: Retos 3 y 4 - 40 min)
    ├── index.json                         # Manifiesto de Killercoda Parte 2
    ├── background.sh / foreground.sh      # Aprovisionamiento y sincronización de sesión
    ├── intro.md / finish.md               # Briefing y post-mortem final
    ├── step3.md y step4.md                # Retos 3 (Triaje OverlayFS + YARA) y 4 (Bastionado CIS)
    ├── step3/ y step4/                    # Scripts de verificación y scoring
    └── assets/                            # Recursos, scoring client y pistas
```

---

## 🚀 Despliegue en Killercoda

1. Vincula este repositorio con tu cuenta y perfil de creador en [Killercoda](https://killercoda.com/).
2. Asegúrate de activar **GitHub Pages** en la configuración del repositorio (`Settings > Pages > Source: Deploy from a branch > Branch: master, Folder: /docs`).
3. Al iniciar el escenario, `background.sh` aprovisionará silenciosamente el entorno e instalará `hint` en el sistema.
4. El estudiante introduce su alias en `foreground.sh` y sus avances se reflejan en tiempo real en la web del Leaderboard.
