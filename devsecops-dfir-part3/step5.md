# Desafío 5 (Bonus): Auditoría con Trivy y Firma Criptográfica de Imágenes con Cosign

**Puntuación:** 250 puntos (Bonus adicional sobre la base de 1000)  
**Tiempo estimado:** 25 - 35 minutos  
**Directorio de trabajo:** `/root/shift-left/`  
**Registro local:** `localhost:5000`

---

## 1. Escenario de la Amenaza

Durante la fase de investigación del incidente, el equipo de seguridad detectó que el atacante no solo manipuló el runner en ejecución, sino que publicó una imagen manipulada en el registro privado corporativo (`localhost:5000/victim-service:v1.0`).

Tu misión como ingeniero DevSecOps es auditar exhaustivamente esta imagen, identificar las vulnerabilidades y secretos filtrados, construir una versión endurecida y firmarla digitalmente con **Cosign** para que el clúster valide su autenticidad antes de autorizar cualquier despliegue.

---

## 2. Fase 1: Auditoría de la Imagen Comprometida con Trivy

Accede al directorio de trabajo en la terminal:

```bash
cd /root/shift-left
```

### Escaneo de Vulnerabilidades del Sistema Operativo y Paquetes
Ejecuta **Trivy** sobre la imagen alojada en el registro local, filtrando por severidad crítica:

```bash
trivy image --severity CRITICAL localhost:5000/victim-service:v1.0
```

Observarás que la imagen utiliza una base desactualizada con múltiples vulnerabilidades sin parchear clasificadas como CRITICAL.

### Escaneo de Secretos Incrustados en Capas (Secret Scanning)
Audita si los desarrolladores o el atacante dejaron secretos persistidos en el sistema de ficheros o variables de entorno:

```bash
trivy image --scanners secret localhost:5000/victim-service:v1.0
```

Identificarás claves de API sensibles y credenciales de base de datos incrustadas mediante directivas `ENV` en el sistema de capas de la imagen.

---

## 3. Fase 2: Remediación y Construcción de Imagen Segura

Examina el archivo de definición original en `/root/shift-left/Dockerfile.vulnerable`:

```bash
cat /root/shift-left/Dockerfile.vulnerable
```

Crea un archivo saneado y endurecido denominado `Dockerfile.hardened`:

```bash
nano /root/shift-left/Dockerfile.hardened
```

Aplica las siguientes buenas prácticas DevSecOps:
1. **Imagen Base Minimalista y Actualizada**: Utiliza una versión reciente y limpia, como `alpine:3.20` o `alpine:latest`.
2. **Eliminación Total de Secretos**: No declares contraseñas ni claves API en directivas `ENV` o `ARG`. Las credenciales deben ser provistas en tiempo de ejecución a través de secretos cifrados o gestores de claves externos.
3. **Usuario No Privilegiado**: Configura la ejecución bajo un usuario sin privilegios para mitigar potenciales escaladas:
   ```dockerfile
   RUN addgroup -S appgroup && adduser -S appuser -G appgroup
   USER appuser
   ```

Ejemplo de estructura recomendada para `Dockerfile.hardened`:

```dockerfile
FROM alpine:3.20

RUN apk update && apk add --no-cache bash

WORKDIR /app
COPY app.sh /app/app.sh
RUN chmod +x /app/app.sh

RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

ENTRYPOINT ["/app/app.sh"]
```

### Construcción y Publicación en el Registro
Compila la nueva imagen con la etiqueta `hardened` y súbela al registro local:

```bash
docker build -t localhost:5000/victim-service:hardened -f /root/shift-left/Dockerfile.hardened /root/shift-left
docker push localhost:5000/victim-service:hardened
```

Valida con Trivy que la nueva imagen tiene **0 vulnerabilidades críticas y 0 secretos**:

```bash
trivy image --severity CRITICAL localhost:5000/victim-service:hardened
trivy image --scanners secret localhost:5000/victim-service:hardened
```

---

## 4. Fase 3: Generación de Claves y Firma Criptográfica con Cosign

Para asegurar que únicamente artefactos autorizados e íntegros puedan ejecutarse, utilizaremos **Cosign** para generar un par de claves asimétricas y firmar el digest del contenedor en el registro.

### Generación del Par de Claves
Dentro de `/root/shift-left`, ejecuta la utilidad de generación de claves. Para automatizar este entorno de laboratorio sin requerir una contraseña interactiva, establece la variable `COSIGN_PASSWORD=""`:

```bash
cd /root/shift-left
COSIGN_PASSWORD="" cosign generate-key-pair
```

Se generarán dos ficheros:
- `cosign.key`: Clave privada (utilizada exclusivamente por el pipeline de compilación).
- `cosign.pub`: Clave pública (distribuida a los nodos del clúster o admission controllers para verificar la imagen).

### Firma de la Imagen en el Registro
Firma la imagen endurecida alojada en `localhost:5000/victim-service:hardened`:

```bash
COSIGN_PASSWORD="" cosign sign --yes --key cosign.key localhost:5000/victim-service:hardened
```

Cosign calculará el hash criptográfico (SHA256 digest) del manifiesto OCI y almacenará la firma directamente en el registro bajo el tag `.sig`.

### Verificación de Autenticidad
Comprueba que la firma es matemáticamente válida empleando la clave pública:

```bash
cosign verify --key cosign.pub localhost:5000/victim-service:hardened
```

Si la salida muestra `Verification for localhost:5000/victim-service:hardened --` y el payload de la firma, la cadena de confianza ha quedado establecida con éxito.

---

## 5. Validación y Entrega

Una vez completados los pasos anteriores, ejecuta el script de validación automatizada:

```bash
/step5/verify.sh
```

El validador comprobará:
1. Conectividad y respuesta del registro local en `localhost:5000`.
2. Existencia de `localhost:5000/victim-service:hardened`.
3. Presencia de `cosign.pub`.
4. Firma criptográfica válida confirmada con Cosign.
5. Cero vulnerabilidades CRITICAL reportadas por Trivy.
6. Cero secretos filtrados reportados por Trivy.

Tras la validación, el cliente registrará los **+250 puntos** y actualizará tu estatus a **Operativo Élite** en el [Leaderboard](https://rickyallitt.github.io/Taller-Alan-Turing).
