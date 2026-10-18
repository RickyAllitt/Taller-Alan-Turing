# Taller Completado: Post-Mortem y Arquitectura de Confianza Zero Trust

Enhorabuena, has completado con éxito la **Parte 3 (Bonus Track)** y con ello el ciclo integral del taller de seguridad en contenedores del **CPIFP Alan Turing**.

---

## Síntesis Técnica del Taller Completo

A lo largo de los 5 desafíos has cubierto el ciclo de vida completo de un incidente de seguridad en entornos cloud-native:

1. **Fase Ofensiva (Desafíos 1 y 2)**:
   - Comprensión de vectores de ataque en pipelines CI/CD y exfiltración de secretos en memoria de procesos (`/proc/$PID/environ`).
   - Abuso de privilegios y montajes inseguros del socket de Docker (`/var/run/docker.sock`) para escapar del espacio de nombres y tomar el control del kernel anfitrión.

2. **Fase Defensiva y Respuesta a Incidentes (Desafíos 3 y 4)**:
   - Triaje forense de sistemas de ficheros en capas (Docker OverlayFS / UpperDir) y creación de reglas YARA para la caza y detección de implantes maliciosos.
   - Bastionado en tiempo de ejecución conforme al **CIS Docker Benchmark**: ejecución sin privilegios (`USER non-root`), sistema de ficheros de sólo lectura (`read_only: true`), eliminación de capacidades (`cap_drop: ["ALL"]`) y bloqueo de escaladas (`no-new-privileges: true`).

3. **Fase DevSecOps Shift-Left y Cadena de Suministro (Desafío 5)**:
   - Integración de escaneo automatizado de vulnerabilidades y detección de secretos en repositorios OCI mediante **Trivy**.
   - Establecimiento de procedencia y firma criptográfica inmutable mediante **Cosign** (Sigstore), garantizando que ningún contenedor no firmado pueda desplegarse en entornos productivos.

---

## Marcos y Estándares de Referencia de la Industria

Para continuar profundizando en estos conceptos, se recomienda la consulta de los siguientes estándares internacionales:

- **NIST SP 800-190**: *Application Container Security Guide*. Directrices fundamentales sobre riesgos en imágenes, registros, orquestadores y hosts.
- **CIS Docker Benchmark v1.6.0**: Recomendaciones prescriptivas de configuración de seguridad para el motor Docker en producción.
- **SLSA (Supply chain Levels for Software Artifacts)**: Marco de ciberseguridad impulsado por Google y OpenSSF para garantizar la integridad de artefactos de software desde el código fuente hasta la entrega.
- **CNCF Cloud Native Security Whitepaper**: Arquitectura de referencia de seguridad nativa en la nube y principios Zero Trust.

---

## Marcador Final y Certificación de Resultados

Puedes consultar tu posición final, desglose de retos y tiempo de resolución en el panel interactivo del taller:

- **Leaderboard Oficial:** [https://rickyallitt.github.io/Taller-Alan-Turing](https://rickyallitt.github.io/Taller-Alan-Turing)

Gracias por tu dedicación técnica y rigurosidad operativa durante este taller en el **CPIFP Alan Turing**.
