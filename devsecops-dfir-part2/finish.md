# Post-Mortem Operativo: Seguridad en la Cadena de Suministro y Defensa de Contenedores

## Resumen de la Evaluación Técnica

Este ejercicio práctico ha evaluado el ciclo de vida completo de una intrusión en la cadena de suministro basada en contenedores: acceso inicial mediante ejecución de código en pipelines, extracción de credenciales en memoria virtual, escalada de privilegios a través de la exposición de sockets UNIX, análisis forense de artefactos post-explotación e implementación de controles de bastionado en profundidad.

```text
Matriz de Cadena de Ataque vs Controles Defensivos
────────────────────────────────────────────────────────────────────────────────────────
Técnica Atacante (MITRE ATT&CK)        Condición Explotada          Control Remediado
────────────────────────────────────────────────────────────────────────────────────────
T1195.002 (Ataque a Cadena Suministro) Espacio PID compartido       Aislamiento de PID,
                                       Secretos en memoria proceso  credenciales OIDC (Vault/AWS)
────────────────────────────────────────────────────────────────────────────────────────
T1611 (Escape al Host)                 Montaje docker.sock          Eliminación del socket;
                                       Contexto de usuario root     compiladores sin demonio
────────────────────────────────────────────────────────────────────────────────────────
T1059.004 (Persistencia en Shell Unix) Capa modificable contenedor  read_only: true (OverlayFS)
                                       Ejecución sin restricciones  cap_drop: [ALL], non-root
────────────────────────────────────────────────────────────────────────────────────────
```

---

## Hallazgos Arquitectónicos y Recomendaciones para la Industria

### 1. Aislamiento de Secretos en Memoria
- **Deficiencia Observada:** Las credenciales de despliegue de larga duración (`DEPLOY_PRODUCTION_KEY`) se inyectaron directamente en el proceso inicial del contenedor, haciéndolas accesibles vía `/proc/1/environ` para cualquier proceso dentro del mismo espacio de nombres.
- **Estándar Empresarial:** Los agentes de compilación en integración continua nunca deben almacenar credenciales estáticas de infraestructura en la nube. Las identidades de las cargas de trabajo deben gestionarse en tiempo de ejecución mediante tokens **OpenID Connect (OIDC)** de corta duración (*short-lived*), integrados con gestores de secretos mediante controladores CSI o almacenes externos como HashiCorp Vault o AWS Secrets Manager.

### 2. Eliminación de Docker-Outside-of-Docker (DooD)
- **Deficiencia Observada:** Montar `/var/run/docker.sock` otorga control equivalente a root en el kernel del host a cualquier proceso que se ejecute dentro del contenedor.
- **Estándar Empresarial:** Los clústeres de compilación en producción deben deshabilitar el socket del demonio Docker para tareas de CI. La generación de imágenes de contenedor debe migrar a herramientas sin demonio (*daemonless*) que operan en espacios de nombres de usuario sin privilegios:
  - **Google Kaniko:** Compila imágenes de contenedor dentro de contenedores o clústeres de Kubernetes sin requerir el demonio Docker.
  - **Buildah / Podman:** Emplea espacios de nombres de usuario (`userns`) para compilar imágenes OCI en modo rootless.
  - **Sysbox:** Runtime OCI especializado que encapsula demonios Docker dentro de contenedores de sistema aislados sin privilegios.

### 3. Triaje Forense Digital a través de Controladores de Almacenamiento
- **Metodología Observada:** El análisis estático de incidentes en contenedores se realiza de forma más segura y fiable inspeccionando el directorio **UpperDir de OverlayFS** desde el sistema anfitrión. Esto preserva los metadatos del sistema de ficheros, aísla los implantes maliciosos sin ejecutar binarios sospechosos y facilita la generación rápida de firmas de detección con YARA.
- **Estándar Empresarial:** La detección de amenazas en tiempo de ejecución debe automatizarse mediante sensores a nivel de kernel basados en eBPF (**Cilium Tetragon**, **Falco** o **Tracee**) para detectar llamadas al sistema anómalas, cambios en la jerarquía de procesos y conexiones de red no autorizadas en tiempo real.

### 4. Bastionado de Contenedores mediante Defensa en Profundidad
- **Implementación Observada:** Proteger cargas de trabajo requiere una estrategia en capas. La combinación de `read_only: true`, `cap_drop: [ALL]`, `security_opt: [no-new-privileges:true]` y la ejecución con usuarios sin privilegios (`user: 10001:10001`) neutraliza los vectores de persistencia y previene las escaladas de privilegios hacia el sistema anfitrión.

---

## Marcos Normativos y Referencias de Cumplimiento

Para profundizar en las especificaciones de seguridad y arquitecturas de referencia:
- **Center for Internet Security:** [CIS Docker Benchmark v1.6.0](https://www.cisecurity.org/benchmark/docker)
- **National Institute of Standards and Technology:** [NIST SP 800-190: Application Container Security Guide](https://csrc.nist.gov/publications/detail/sp/800-190/final)
- **Open Source Security Foundation (OpenSSF):** [Supply-chain Levels for Software Artifacts (SLSA v1.0)](https://slsa.dev/)
- **Matriz MITRE ATT&CK para Empresas:** [Modelo de Amenazas en Contenedores](https://attack.mitre.org/matrices/enterprise/containers/)
- **Cloud Native Computing Foundation (CNCF):** [Libro Blanco de Seguridad Cloud Native v2](https://github.com/cncf/tag-security/blob/main/security-whitepaper/cloud-native-security-whitepaper.md)

---

## Finalización del Cyber Range y Marcador de la Promoción

Los resultados finales y la telemetría de tus ejercicios han quedado registrados en el sistema de evaluación centralizado.
- Puntuación Máxima Posible: 1.000 Puntos Base.
- Puedes consultar la clasificación final, las marcas de tiempo y el progreso de tus compañeros en el marcador en vivo:
  **https://rickyallitt.github.io/Taller-Alan-Turing**
