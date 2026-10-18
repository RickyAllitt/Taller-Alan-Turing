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

## Objetivos del Desafío

En este laboratorio avanzado utilizarás dos de las herramientas líderes en el ecosistema DevSecOps de la Cloud Native Computing Foundation (CNCF):

- **Trivy (Aqua Security)**: Escáner integral de seguridad para contenedores, dependencias y secretos.
- **Cosign (Sigstore / OpenSSF)**: Estándar para firma criptográfica, verificación y procedencia de contenedores sin sobrecarga de infraestructura.

Completar este desafío te otorgará:
- **+250 Puntos Bonus** adicionales (puntuación máxima alcanzable: 1250 puntos).
- La distinción **Operativo Élite** en el Marcador en Tiempo Real.

---

## Vinculación de Tu Puntuación Anterior

Si completaste la Parte 1 y la Parte 2, vincula tu expediente introduciendo en la terminal interactiva:

```bash
score register <tu_indicativo_anterior>
```

El cliente recuperará tu registro histórico y sumará los puntos del Desafío 5 a tu puntuación global.

Pulsa en **Continuar** para acceder a la guía técnica del desafío.
