# Desafío Bonus (Nivel Avanzado): DevSecOps Shift-Left & Confianza Criptográfica en la Cadena de Suministro

Bienvenido al desafío avanzado del taller práctico de ciberseguridad del **CPIFP Alan Turing**.

Este escenario opcional está diseñado para operativos que hayan completado con éxito las **Partes 1 y 2** y deseen profundizar en los estándares modernos de aseguramiento de la cadena de suministro de software (Supply Chain Security / SLSA Framework), o para aquellos que deseen poner a prueba sus habilidades técnicas de forma autónoma.

---

## Contexto Operativo y Arquitectura

En las fases anteriores comprobaste cómo un atacante puede aprovechar credenciales filtradas para envenenar un runner CI/CD y escapar del aislamiento mediante el socket de Docker. Posteriormente realizaste el triaje forense en OverlayFS y aplicaste bastionado sobre el demonio y el contenedor en tiempo de ejecución.

Sin embargo, en arquitecturas cloud-native empresariales (Kubernetes, Docker Swarm, ECS), la primera línea de defensa debe situarse **antes de que los artefactos lleguen al entorno de ejecución (estrategia Shift-Left)**:

1. **Auditoría Estática de Vulnerabilidades y Secretos**: Toda imagen de contenedor debe ser analizada antes de su publicación para certificar la ausencia de vulnerabilidades explotables (CVEs críticas) y credenciales en texto plano incrustadas en las capas del sistema de ficheros.
2. **Confianza e Inmutabilidad Criptográfica (Image Signing)**: Es fundamental garantizar que los nodos del clúster únicamente ejecuten imágenes firmadas digitalmente por identidades o autoridades de confianza reconocidas por la organización, impidiendo el despliegue de imágenes modificadas o suplantadas por actores maliciosos.

---

## Objetivos del Desafío Bonus

En este laboratorio avanzado consolidarás la seguridad en la cadena de suministro y el despliegue mediante dos retos especializados:

1. **Desafío 5 (Bonus 1 - 125 pts)**: Auditoría estática de vulnerabilidades críticas y filtración de secretos con **Trivy**, remediación en `Dockerfile.hardened` y firma criptográfica inmutable con **Cosign** (Sigstore / OpenSSF).
2. **Desafío 6 (Bonus 2 - 125 pts)**: Implementación de una puerta de admisión automatizada (**Admission Gate / Policy as Code**) en `/root/shift-left/admission_gate.sh` que valide firmas y escaneos antes de autorizar el despliegue del contenedor con directivas CIS en tiempo de ejecución.

Completar ambos desafíos te otorgará:
- **+250 Puntos Bonus** adicionales (125 pts por reto, puntuación máxima alcanzable: 1250 puntos).
- La distinción **Operativo Élite** en el Marcador en Tiempo Real.

---

## Vinculación de Tu Puntuación Anterior

Si completaste la Parte 1 y la Parte 2, vincula tu expediente introduciendo en la terminal interactiva tu nombre y tu PIN:

```bash
score resume <tu_indicativo_anterior> <tu_pin>
```

El cliente recuperará tu registro histórico y sumará los puntos de los retos adicionales a tu puntuación global.

Pulsa en **Continuar** para acceder a la guía técnica del desafío.
