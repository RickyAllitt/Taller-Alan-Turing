# Desafío 6 (Bonus): Puerta de Admisión Automatizada y Despliegue Zero Trust

**Puntuación:** 125 puntos (Bonus adicional sobre la base de 1000)  
**Tiempo estimado:** 25 - 35 minutos  
**Directorio de trabajo:** `/root/shift-left/`  
**Objetivo final:** `/root/shift-left/admission_gate.sh`

---

## 1. Escenario de la Amenaza: The Rogue Deployment Problem

Haber firmado la imagen con Cosign y escaneado con Trivy en el Desafío 5 es una victoria crítica en la cadena de suministro. Sin embargo, en un entorno de producción real, **las políticas de seguridad solo son efectivas si se aplican de forma obligatoria e ineludible**.

Si un desarrollador descuidado o un atacante con acceso al demonio intenta desplegar una imagen no firmada, obsoleta o con secretos expuestos (como `localhost:5000/victim-service:v1.0`), el sistema debe interceptar la solicitud y denegar el despliegue de forma automática antes de que el contenedor llegue a ejecutarse.

En arquitecturas cloud-native empresariales (Kubernetes), esta responsabilidad recae en los **Admission Controllers** y motores de **Policy as Code** (como Kyverno, OPA Gatekeeper o Sigstore Policy Controller). 

En este laboratorio, consolidarás todos los conceptos aprendidos a lo largo del taller implementando una **puerta de admisión automatizada (Admission Gate)** en `/root/shift-left/admission_gate.sh`.

---

## 2. Requerimientos de la Puerta de Admisión

Tu script debe residir en `/root/shift-left/admission_gate.sh`, tener permisos de ejecución (`chmod +x`) y aceptar la referencia de la imagen a desplegar como su primer argumento (`$1`):

```bash
/root/shift-left/admission_gate.sh <nombre_o_referencia_de_imagen>
```

El script debe evaluar secuencialmente 3 puertas de control criptográficas y de seguridad antes de autorizar cualquier ejecución:

### Puerta 1: Verificación de Firma Criptográfica (Cosign)
- Debe comprobar que la imagen proporcionada en `$1` posee una firma digital válida generada con la clave pública de la organización (`/root/shift-left/cosign.pub`).
- **Comportamiento ante fallo:** Si la firma no existe o no es matemáticamente válida, debe imprimir un mensaje de rechazo descriptivo y finalizar inmediatamente con un código de salida `exit 1`.

### Puerta 2: Barrera de Vulnerabilidades Críticas (Trivy)
- Debe analizar la imagen con **Trivy**, configurando la herramienta para emitir un código de salida de error si detecta vulnerabilidades de severidad `CRITICAL`.
- **Comportamiento ante fallo:** Si se detectan vulnerabilidades críticas, debe abortar la operación con código de salida `exit 2`.

### Puerta 3: Detección de Secretos en Capas (Trivy Secret Scanner)
- Debe comprobar que no existan credenciales, tokens o claves incrustadas en las capas del artefacto mediante el escáner de secretos de Trivy.
- **Comportamiento ante fallo:** Si se detectan secretos filtrados, debe abortar con código de salida `exit 3`.

---

## 3. Despliegue en Tiempo de Ejecución (Zero Trust Runtime)

Únicamente si las tres puertas anteriores han sido superadas con éxito, el script procederá a desplegar el servicio en producción cumpliendo con las siguientes directivas de bastionado:

1. **Gestión de ciclo de vida:** Limpiar cualquier instancia previa del contenedor para evitar colisiones de nombre (`docker rm -f secure_production_service 2>/dev/null || true`).
2. **Nombre de contenedor:** Debe llamarse obligatoriamente `secure_production_service`.
3. **Modo desacoplado:** Ejecución en segundo plano (`-d`).
4. **Sistema de ficheros inmutable:** Activar el sistema de ficheros de solo lectura (`--read-only`).
5. **Mitigación de escaladas:** Impedir la elevación de privilegios mediante binarios SUID/SGID (`--security-opt no-new-privileges:true`).
6. **Mínimo privilegio en el kernel:** Restringir todas las capacidades del kernel de Linux (`--cap-drop ALL`).
7. **Usuario no privilegiado:** Ejecutar bajo una identidad sin privilegios (por ejemplo, `--user 10001:10001` o el usuario no root declarado en la imagen saneada).
8. **Finalización:** Finalizar con código de salida exitoso `exit 0`.

---

## 4. Pruebas y Validación Manual

Antes de solicitar la validación automatizada, realiza una prueba de doble vía en la terminal:

### Prueba de Denegación (Falso Positivo / Ataque):
Ejecuta la puerta contra la imagen vulnerable original:
```bash
/root/shift-left/admission_gate.sh localhost:5000/victim-service:v1.0
echo "Código de salida: $?"
```
*Resultado esperado:* El script debe detenerse en la Puerta 1 o 2, emitir un mensaje de rechazo y devolver un código de error distinto de 0. No debe crearse ningún contenedor.

### Prueba de Autorización (Despliegue Legítimo):
Ejecuta la puerta contra la imagen que saneaste y firmaste en el Desafío 5:
```bash
/root/shift-left/admission_gate.sh localhost:5000/victim-service:hardened
echo "Código de salida: $?"
```
*Resultado esperado:* Las 3 comprobaciones deben superar con éxito, el contenedor `secure_production_service` debe arrancar en segundo plano y el script debe devolver código 0.

Inspecciona la configuración del contenedor desplegado:
```bash
docker inspect secure_production_service --format 'ReadonlyRootfs: {{.HostConfig.ReadonlyRootfs}} | SecurityOpt: {{.HostConfig.SecurityOpt}} | CapDrop: {{.HostConfig.CapDrop}}'
```

---

## 5. Validación y Entrega

Una vez implementada y probada la lógica de admisión, ejecuta el validador oficial:

```bash
/step6/verify.sh
```

El validador someterá tu script a:
1. Inspección de existencia y permisos de ejecución de `/root/shift-left/admission_gate.sh`.
2. Prueba de rechazo estricta: intento de desplegar la imagen vulnerable (debe abortar y no desplegar).
3. Prueba de aprobación: despliegue de la imagen firmada (debe desplegar y devolver 0).
4. Verificación de ejecución del contenedor `secure_production_service`.
5. Auditoría profunda de las 4 directivas CIS de bastionado en tiempo de ejecución.

Tras superar las pruebas, el cliente registrará los **+125 puntos** adicionales en el [Leaderboard](https://rickyallitt.github.io/Taller-Alan-Turing).
