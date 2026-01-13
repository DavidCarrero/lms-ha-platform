# Topología de Alta Disponibilidad - Moodle

## Arquitectura Actual (Docker Compose)

```
                    Internet/Usuario
                           |
                           | :8080
                           ↓
                   ┌───────────────┐
                   │ nginx-proxy   │  (nginx:alpine)
                   │               │  Load Balancer
                   │  Port: 8080   │  Round-Robin
                   └───────────────┘
                           |
        ┌──────────────────┼──────────────────┐
        |                  |                  |
        ↓                  ↓                  ↓
   ┌─────────┐       ┌─────────┐       ┌─────────┐
   │  web1   │       │  web2   │       │  web3   │
   │ :80     │       │ :80     │       │ :80     │
   │ Moodle  │       │ Moodle  │       │ Moodle  │
   │ PHP 8.3 │       │ PHP 8.3 │       │ PHP 8.3 │
   └─────────┘       └─────────┘       └─────────┘
        |                  |                  |
        └──────────────────┼──────────────────┘
                           |
           ┌───────────────┼───────────────┐
           ↓               ↓               ↓
    ┌───────────┐   ┌───────────────┐   
    │  redis    │   │   moodle-db   │   
    │ Redis 7   │   │  MariaDB 11.7 │   
    │ :6379     │   │  Port: 3306   │   
    │ Sessions  │   └───────────────┘   
    └───────────┘            |
         |            ┌──────┴──────┐
         |            |             |
    ┌────────────┐ ┌──────────┐ ┌──────────┐
    │redis_data  │ │ db_data  │ │moodledata│
    │  (volume)  │ │ (volume) │ │ (volume) │
    └────────────┘ └──────────┘ └──────────┘
```

## Componentes

### 1. Nginx Proxy (1 instancia)
- **Imagen**: nginx:alpine
- **Función**: Load Balancer / Reverse Proxy
- **Puerto expuesto**: 8080 → 80
- **Algoritmo**: Round-Robin
- **Backends**: web1, web2, web3
- **Características**:
  - Compresión gzip habilitada
  - Timeouts ajustados para Moodle (300s)
  - Max body size: 100MB
  - Health monitoring con stub_status

### 2. Servidores Web Moodle (3 réplicas - Alta Disponibilidad)
- **Imagen**: moodle-web:latest (PHP 8.3 + Apache)
- **Réplicas**: 3 instancias idénticas
- **Puerto interno**: 80 (no expuesto directamente)
- **Extensiones PHP**: gd, intl, mbstring, xml, zip, pdo_mysql, mysqli, opcache, soap, exif, **redis**
- **Volúmenes compartidos**:
  - Código: `./:/var/www/html` (bind mount)
  - Datos: `moodledata` (named volume)

### 3. Redis (Gestión Centralizada de Sesiones)
- **Imagen**: redis:7-alpine
- **Puerto interno**: 6379
- **Función**: Almacenamiento centralizado de sesiones PHP
- **Características**:
  - Versión: Redis 7 (última estable)
  - Healthcheck con `redis-cli ping`
  - Volumen persistente: `redis_data`
  - **Ventajas**:
    - ✅ Sesiones compartidas entre los 3 servidores web
    - ✅ No se requieren sticky sessions
    - ✅ Alta disponibilidad real (cualquier servidor puede servir cualquier sesión)
    - ✅ Persistencia de sesiones ante reinicios
    - ✅ Mejor rendimiento que sesiones en filesystem

### 4. Base de Datos (1 instancia)
- **Imagen**: mariadb:11.7
- **Puerto interno**: 3306
- **Características**:
  - Auto-upgrade habilitado
  - Healthcheck configurado
  - Volumen persistente: `db_data`

## Estado Actual de Servicios

```bash
docker ps
```

| Container      | Status | Ports                    |
|---------------|--------|--------------------------|
| apache-proxy  | Up     | 0.0.0.0:8080->80/tcp    |
| moodle-web-1  | Up     | 80/tcp (internal)        |
| moodle-web-2  | Up     | 80/tcp (internal)        |
| moodle-web-3  | Up     | 80/tcp (internal)        |
| moodle-redis  | Up     | 6379/tcp (internal)      |
| moodle-db     | Healthy| 3306/tcp (internal)      |

## Ventajas de la Arquitectura Actual

✅ **Alta Disponibilidad Real**: Sesiones centralizadas en Redis permiten que cualquier servidor atienda cualquier usuario  
✅ **Escalabilidad Horizontal**: Fácil agregar más réplicas web sin preocuparse por sesiones  
✅ **Balanceo de Carga sin Sticky Sessions**: No se requiere afinidad de sesión (session affinity)  
✅ **Punto único de entrada**: Apache proxy centraliza el acceso  
✅ **Persistencia de Sesiones**: Sesiones sobreviven reinicios de contenedores web  
✅ **Healthchecks**: Base de datos y Redis con monitoreo de salud  
✅ **Mejor Rendimiento**: Redis es más rápido que sesiones en filesystem

## Limitaciones Actuales (Desarrollo Local)

⚠️ **Archivos compartidos vía bind-mount**: En producción necesita almacenamiento compartido (NFS/S3)  
⚠️ **Cron jobs duplicados**: Cada réplica ejecuta tareas programadas (necesita coordinación)  
⚠️ **Base de datos single-point-of-failure**: Solo 1 instancia sin replicación  
⚠️ **Redis single-point-of-failure**: En producción considerar Redis Sentinel o Redis Cluster

---

# Gestión de Sesiones con Redis

## ¿Por qué Redis para sesiones?

En una arquitectura de alta disponibilidad con múltiples servidores web, las sesiones PHP tradicionales (almacenadas en filesystem) presentan un problema: cada servidor tiene sus propias sesiones locales. Esto significa que si un usuario inicia sesión en `web1`, y su siguiente request es balanceado a `web2`, perderá su sesión.

**Soluciones tradicionales:**
- **Sticky Sessions**: Configurar el load balancer para que siempre envíe al usuario al mismo servidor
  - ❌ Problema: Si ese servidor se cae, el usuario pierde su sesión
  - ❌ Problema: Distribución desigual de carga
  - ❌ Problema: Complicado con proxies intermedios

- **NFS para sesiones**: Compartir el directorio de sesiones vía NFS
  - ❌ Problema: Lento (I/O de filesystem)
  - ❌ Problema: File locking issues con alta concurrencia
  - ❌ Problema: Single point of failure (el NFS)

**Solución óptima: Redis**
- ✅ **Centralizado**: Todas las sesiones en un solo lugar
- ✅ **Rápido**: In-memory, mucho más rápido que filesystem
- ✅ **Stateless backends**: Cualquier servidor web puede atender cualquier request
- ✅ **No requiere sticky sessions**: Simplifica el load balancer
- ✅ **Persistencia**: Las sesiones sobreviven reinicios de servidores web
- ✅ **Escalable**: Redis puede escalar con Sentinel/Cluster
- ✅ **TTL automático**: Redis puede expirar sesiones antiguas automáticamente

## Configuración de Redis en Moodle

### 1. docker-compose.yml

Se agregó el servicio Redis:

```yaml
redis:
  image: redis:7-alpine
  container_name: moodle-redis
  restart: unless-stopped
  volumes:
    - redis_data:/data
  healthcheck:
    test: ["CMD", "redis-cli", "ping"]
    interval: 10s
    timeout: 5s
    retries: 5
```

Y el volumen persistente:

```yaml
volumes:
  db_data:
  moodledata:
  redis_data:  # Nuevo volumen para datos de Redis
```

### 2. Dockerfile

Se instaló la extensión PHP `redis` vía PECL:

```dockerfile
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ... \
    && docker-php-ext-install -j$(nproc) \
        gd intl mbstring xml zip pdo_mysql mysqli opcache soap exif \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && a2enmod rewrite headers expires \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
```

### 3. config.php

Se configuró Moodle para usar Redis como session handler:

```php
// Redis session management for high availability
$CFG->session_handler_class = '\core\session\redis';
$CFG->session_redis_host = 'redis';
$CFG->session_redis_port = 6379;
$CFG->session_redis_database = 0;
$CFG->session_redis_prefix = 'moodle_sess_';
$CFG->session_redis_acquire_lock_timeout = 120;
$CFG->session_redis_lock_expire = 7200;
```

**Explicación de parámetros:**

- `session_handler_class`: Clase de Moodle que maneja sesiones con Redis
- `session_redis_host`: Hostname del contenedor Redis (service discovery de Docker)
- `session_redis_port`: Puerto estándar de Redis (6379)
- `session_redis_database`: Base de datos Redis a usar (0 = default)
- `session_redis_prefix`: Prefijo para las keys de sesión en Redis
- `session_redis_acquire_lock_timeout`: Tiempo máximo (segundos) para adquirir lock de sesión
- `session_redis_lock_expire`: Tiempo de expiración del lock (segundos)

## Despliegue y Verificación

### 1. Reconstruir la imagen (para instalar phpredis)

```bash
docker compose build
```

### 2. Levantar los servicios

```bash
docker compose up -d
```

### 3. Verificar que Redis está corriendo

```bash
# Ver logs de Redis
docker logs moodle-redis

# Verificar healthcheck
docker inspect moodle-redis | grep -A5 Health

# Conectarse a Redis CLI
docker exec -it moodle-redis redis-cli ping
# Debería responder: PONG
```

### 4. Verificar extensión PHP redis

```bash
docker exec moodle-web-1 php -m | grep redis
# Debería mostrar: redis
```

### 5. Probar sesiones en producción

1. Accede a http://localhost:8080
2. Inicia sesión en Moodle
3. Verifica que puedes navegar sin perder sesión
4. Opcional: Reinicia uno de los servidores web
   ```bash
   docker restart moodle-web-2
   ```
5. Actualiza la página - la sesión debe persistir

### 6. Inspeccionar sesiones en Redis (Debugging)

```bash
# Conectarse a Redis CLI
docker exec -it moodle-redis redis-cli

# Listar todas las keys de sesión
KEYS moodle_sess_*

# Ver una sesión específica (ejemplo)
GET moodle_sess_abc123def456

# Ver cuántas sesiones hay
DBSIZE

# Salir
exit
```

## Ventajas de esta Implementación

| Aspecto | Antes (Sin Redis) | Ahora (Con Redis) |
|---------|-------------------|-------------------|
| **Sesiones** | Locales a cada servidor | Centralizadas |
| **Sticky Sessions** | Requerido | No necesario |
| **Failover** | Pérdida de sesión | Sesión preservada |
| **Escalabilidad** | Limitada | Total |
| **Rendimiento** | Filesystem I/O | In-memory (rápido) |
| **Persistencia** | Se pierde al reiniciar | Persiste en volumen |

## Consideraciones para Producción en OCI

### Opción 1: Redis en Kubernetes (OKE)

Desplegar Redis como StatefulSet:

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis
spec:
  serviceName: redis
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        ports:
        - containerPort: 6379
        volumeMounts:
        - name: redis-data
          mountPath: /data
  volumeClaimTemplates:
  - metadata:
      name: redis-data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: oci-bv
      resources:
        requests:
          storage: 10Gi
```

### Opción 2: OCI Cache with Redis (Servicio Gestionado)

En producción, Oracle ofrece **OCI Cache with Redis**, un servicio gestionado que:

- ✅ Alta disponibilidad automática
- ✅ Backups automáticos
- ✅ Monitoreo integrado
- ✅ Escalado vertical sin downtime
- ✅ Parches de seguridad automáticos

**Configuración en config.php para OCI Cache:**

```php
$CFG->session_handler_class = '\core\session\redis';
$CFG->session_redis_host = 'redis-endpoint.oci.oraclecloud.com';  // Endpoint del servicio OCI
$CFG->session_redis_port = 6379;
$CFG->session_redis_auth = 'your-redis-password';  // Password del servicio
$CFG->session_redis_database = 0;
$CFG->session_redis_prefix = 'moodle_sess_';
```

### Opción 3: Redis Sentinel (Alta Disponibilidad)

Para HA real sin servicio gestionado, usar **Redis Sentinel**:

```yaml
# 3 nodos Redis (1 master, 2 replicas) + 3 sentinels
# Sentinel monitorea el master y hace automatic failover
```

**Configuración en config.php:**

```php
$CFG->session_handler_class = '\core\session\redis';
$CFG->session_redis_sentinel = ['sentinel1:26379', 'sentinel2:26379', 'sentinel3:26379'];
$CFG->session_redis_sentinel_master = 'mymaster';
$CFG->session_redis_database = 0;
$CFG->session_redis_prefix = 'moodle_sess_';
```

## Troubleshooting

### Error: "Cannot connect to Redis"

```bash
# Verificar que Redis está corriendo
docker ps | grep redis

# Verificar conectividad desde un contenedor web
docker exec moodle-web-1 ping -c 2 redis

# Verificar logs de Redis
docker logs moodle-redis
```

### Error: "Class 'Redis' not found"

```bash
# Verificar que la extensión está instalada
docker exec moodle-web-1 php -m | grep redis

# Si no aparece, reconstruir la imagen
docker compose build
docker compose up -d
```

### Sesiones no persisten

```bash
# Verificar configuración en config.php
docker exec moodle-web-1 grep -A7 "session_handler_class" /var/www/html/config.php

# Ver sesiones en Redis
docker exec -it moodle-redis redis-cli KEYS "moodle_sess_*"
```

### Performance: Redis lento

```bash
# Ver estadísticas de Redis
docker exec -it moodle-redis redis-cli INFO stats

# Ver comandos lentos
docker exec -it moodle-redis redis-cli SLOWLOG GET 10

# Monitorear comandos en tiempo real
docker exec -it moodle-redis redis-cli MONITOR
```

---

# Migración a Oracle Cloud Infrastructure (OCI)

## Opción 1: Oracle Container Engine for Kubernetes (OKE) - **RECOMENDADO**

### Arquitectura en OCI con Kubernetes

```
                        Internet
                           |
                           ↓
                  ┌────────────────┐
                  │  OCI Load      │
                  │  Balancer      │  Público
                  │  (Flexible)    │  HTTPS + SSL
                  └────────────────┘
                           |
                  Ingress Controller
                     (NGINX/Traefik)
                           |
        ┌──────────────────┼──────────────────┐
        |                  |                  |
        ↓                  ↓                  ↓
   ┌─────────┐       ┌─────────┐       ┌─────────┐
   │  Pod 1  │       │  Pod 2  │       │  Pod 3  │
   │ Moodle  │       │ Moodle  │       │ Moodle  │
   │ Web     │       │ Web     │       │ Web     │
   └─────────┘       └─────────┘       └─────────┘
        |                  |                  |
        └──────────────────┼──────────────────┘
                           |
                    Service (ClusterIP)
                           |
                           ↓
                   ┌───────────────┐
                   │   StatefulSet │
                   │   MariaDB     │
                   │   + PVC       │
                   └───────────────┘
                           |
                    OCI Block Volume
                    (Persistent Storage)
```

### Recursos Necesarios en OCI

#### 1. **Crear Cluster OKE**
```bash
# Usando OCI CLI
oci ce cluster create \
  --compartment-id <compartment-ocid> \
  --name moodle-cluster \
  --kubernetes-version v1.28.2 \
  --vcn-id <vcn-ocid> \
  --service-lb-subnet-ids '["<subnet-ocid>"]'
```

#### 2. **Configurar kubectl**
```bash
oci ce cluster create-kubeconfig \
  --cluster-id <cluster-ocid> \
  --file $HOME/.kube/config \
  --region us-ashburn-1
```

#### 3. **Crear Oracle Container Registry (OCIR)**
```bash
# Login a OCIR
docker login <region>.ocir.io
# Formato: <region>.ocir.io/<tenancy-namespace>/<repo-name>:<tag>

# Tag y push de imágenes
docker tag moodle-web:latest <region>.ocir.io/<namespace>/moodle-web:latest
docker push <region>.ocir.io/<namespace>/moodle-web:latest
```

#### 4. **Configurar File Storage Service (FSS) - Almacenamiento Compartido**
```bash
# Crear File System para moodledata
oci fs file-system create \
  --compartment-id <compartment-ocid> \
  --availability-domain <AD> \
  --display-name moodle-shared-data
```

#### 5. **Desplegar en Kubernetes**

**a) ConfigMap para configuración:**
```yaml
# k8s/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: moodle-config
data:
  MOODLE_DBHOST: "mariadb-service"
  MOODLE_DBNAME: "moodle"
  MOODLE_DBUSER: "moodle"
```

**b) Secret para credenciales:**
```yaml
# k8s/secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: moodle-secrets
type: Opaque
stringData:
  MYSQL_ROOT_PASSWORD: "rootpass"
  MYSQL_PASSWORD: "moodle"
  MOODLE_DBPASS: "moodle"
```

**c) PersistentVolumeClaim para DB:**
```yaml
# k8s/pvc-db.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mariadb-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: oci-bv  # OCI Block Volume
  resources:
    requests:
      storage: 50Gi
```

**d) StatefulSet para MariaDB:**
```yaml
# k8s/mariadb-statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mariadb
spec:
  serviceName: mariadb-service
  replicas: 1
  selector:
    matchLabels:
      app: mariadb
  template:
    metadata:
      labels:
        app: mariadb
    spec:
      containers:
      - name: mariadb
        image: mariadb:11.7
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: moodle-secrets
              key: MYSQL_ROOT_PASSWORD
        - name: MYSQL_DATABASE
          valueFrom:
            configMapKeyRef:
              name: moodle-config
              key: MOODLE_DBNAME
        - name: MYSQL_USER
          valueFrom:
            configMapKeyRef:
              name: moodle-config
              key: MOODLE_DBUSER
        - name: MYSQL_PASSWORD
          valueFrom:
            secretKeyRef:
              name: moodle-secrets
              key: MYSQL_PASSWORD
        - name: MARIADB_AUTO_UPGRADE
          value: "1"
        ports:
        - containerPort: 3306
          name: mysql
        volumeMounts:
        - name: mariadb-data
          mountPath: /var/lib/mysql
        livenessProbe:
          exec:
            command:
            - sh
            - -c
            - "healthcheck.sh --connect --innodb_initialized"
          initialDelaySeconds: 60
          periodSeconds: 10
  volumeClaimTemplates:
  - metadata:
      name: mariadb-data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: oci-bv
      resources:
        requests:
          storage: 50Gi
---
apiVersion: v1
kind: Service
metadata:
  name: mariadb-service
spec:
  selector:
    app: mariadb
  ports:
  - port: 3306
    targetPort: 3306
  clusterIP: None  # Headless service
```

**e) Deployment para Moodle Web (3 réplicas):**
```yaml
# k8s/moodle-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: moodle-web
spec:
  replicas: 3
  selector:
    matchLabels:
      app: moodle-web
  template:
    metadata:
      labels:
        app: moodle-web
    spec:
      containers:
      - name: moodle
        image: <region>.ocir.io/<namespace>/moodle-web:latest
        ports:
        - containerPort: 80
        env:
        - name: MOODLE_DBHOST
          valueFrom:
            configMapKeyRef:
              name: moodle-config
              key: MOODLE_DBHOST
        - name: MOODLE_DBNAME
          valueFrom:
            configMapKeyRef:
              name: moodle-config
              key: MOODLE_DBNAME
        - name: MOODLE_DBUSER
          valueFrom:
            configMapKeyRef:
              name: moodle-config
              key: MOODLE_DBUSER
        - name: MOODLE_DBPASS
          valueFrom:
            secretKeyRef:
              name: moodle-secrets
              key: MOODLE_DBPASS
        volumeMounts:
        - name: moodledata
          mountPath: /var/moodledata
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 5
      volumes:
      - name: moodledata
        persistentVolumeClaim:
          claimName: moodledata-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: moodle-service
spec:
  selector:
    app: moodle-web
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
  type: ClusterIP
```

**f) PVC para datos compartidos (FSS):**
```yaml
# k8s/pvc-moodledata.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: moodledata-pvc
spec:
  accessModes:
    - ReadWriteMany  # FSS permite múltiples pods
  storageClassName: oci-fss
  resources:
    requests:
      storage: 100Gi
```

**g) Ingress con OCI Load Balancer:**
```yaml
# k8s/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: moodle-ingress
  annotations:
    kubernetes.io/ingress.class: "nginx"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    # OCI Load Balancer annotations
    service.beta.kubernetes.io/oci-load-balancer-shape: "flexible"
    service.beta.kubernetes.io/oci-load-balancer-shape-flex-min: "10"
    service.beta.kubernetes.io/oci-load-balancer-shape-flex-max: "100"
spec:
  tls:
  - hosts:
    - moodle.ejemplo.com
    secretName: moodle-tls
  rules:
  - host: moodle.ejemplo.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: moodle-service
            port:
              number: 80
```

#### 6. **Desplegar aplicación**
```bash
# Crear namespace
kubectl create namespace moodle

# Aplicar configuraciones
kubectl apply -f k8s/configmap.yaml -n moodle
kubectl apply -f k8s/secret.yaml -n moodle
kubectl apply -f k8s/pvc-db.yaml -n moodle
kubectl apply -f k8s/pvc-moodledata.yaml -n moodle
kubectl apply -f k8s/mariadb-statefulset.yaml -n moodle
kubectl apply -f k8s/moodle-deployment.yaml -n moodle
kubectl apply -f k8s/ingress.yaml -n moodle

# Verificar
kubectl get pods -n moodle
kubectl get services -n moodle
kubectl get ingress -n moodle
```

#### 7. **Configurar OCI Load Balancer**
El Ingress Controller creará automáticamente un Load Balancer en OCI. Configuración adicional:

```bash
# Obtener IP pública del Load Balancer
kubectl get ingress moodle-ingress -n moodle

# Configurar DNS
# A record: moodle.ejemplo.com -> <LB-PUBLIC-IP>
```

**Panel OCI → Networking → Load Balancers:**
- **Shape**: Flexible (10-100 Mbps auto-scaling)
- **Backend Set**: Pools de pods Kubernetes (automático vía Ingress)
- **Health Checks**: HTTP GET / (configurado en readinessProbe)
- **SSL**: Certificado Let's Encrypt vía cert-manager
- **Listeners**:
  - HTTP (80) → Redirect a HTTPS
  - HTTPS (443) → Backend Set

---

## Opción 2: Instancias de Compute con Docker (Más Simple)

### Arquitectura

```
           OCI Load Balancer (Flexible)
                    |
        ┌───────────┼───────────┐
        ↓           ↓           ↓
   [Compute 1] [Compute 2] [Compute 3]
   Ubuntu +    Ubuntu +    Ubuntu +
   Docker      Docker      Docker
   Moodle      Moodle      Moodle
        |           |           |
        └───────────┼───────────┘
                    |
              [Compute DB]
              MariaDB
              + Block Volume
```

### Pasos

1. **Crear Instancias de Compute** (3 web + 1 DB)
   - Shape: VM.Standard.E4.Flex (2 OCPU, 16GB RAM)
   - OS: Ubuntu 22.04
   - VCN: Crear subnet privada para DB, pública para web

2. **Instalar Docker en cada instancia**
```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker ubuntu
```

3. **Configurar Block Volume para DB**
```bash
# Attach block volume a instancia DB
sudo mkfs.ext4 /dev/sdb
sudo mkdir /mnt/mariadb
sudo mount /dev/sdb /mnt/mariadb
echo "/dev/sdb /mnt/mariadb ext4 defaults 0 0" | sudo tee -a /etc/fstab
```

4. **Desplegar contenedores**
```bash
# En cada instancia web:
docker run -d --name moodle \
  -p 80:80 \
  -e MOODLE_DBHOST=<DB-PRIVATE-IP> \
  -e MOODLE_DBNAME=moodle \
  -e MOODLE_DBUSER=moodle \
  -e MOODLE_DBPASS=<password> \
  -v /mnt/shared-storage:/var/moodledata \
  moodle-web:latest

# En instancia DB:
docker run -d --name mariadb \
  -p 3306:3306 \
  -e MYSQL_ROOT_PASSWORD=<password> \
  -e MYSQL_DATABASE=moodle \
  -e MYSQL_USER=moodle \
  -e MYSQL_PASSWORD=<password> \
  -v /mnt/mariadb:/var/lib/mysql \
  mariadb:11.7
```

5. **Crear Load Balancer en OCI**
   - **Panel OCI → Networking → Load Balancers → Create Load Balancer**
   - **Type**: Load Balancer
   - **Shape**: Flexible (10 Mbps min, 100 Mbps max)
   - **Visibility**: Public
   - **Backend Set**:
     - Add: Compute-1, Compute-2, Compute-3 (port 80)
     - Health Check: HTTP, path `/`, port 80
     - Policy: Round Robin
   - **Listeners**:
     - HTTP (80)
     - HTTPS (443) con certificado SSL

6. **Configurar Security Lists**
```
Ingress Rules:
- 0.0.0.0/0 → 80 (HTTP)
- 0.0.0.0/0 → 443 (HTTPS)
- <LB Subnet> → <Web Subnet> → 80
- <Web Subnet> → <DB Subnet> → 3306

Egress Rules:
- <Web Subnet> → 0.0.0.0/0 (All)
- <DB Subnet> → 0.0.0.0/0 (Updates)
```

---

## Comparación de Opciones

| Característica | OKE (Kubernetes) | Compute + Docker |
|---------------|------------------|------------------|
| **Complejidad** | Alta | Media |
| **Costo Inicial** | Medio-Alto | Bajo |
| **Auto-scaling** | ✅ Nativo | ⚠️ Manual |
| **Alta Disponibilidad** | ✅ Automática | ⚠️ Requiere configuración |
| **Gestión** | Declarativa (YAML) | Manual |
| **Rolling Updates** | ✅ Nativo | ⚠️ Manual |
| **Monitoreo** | ✅ Prometheus/Grafana | Requiere setup |
| **Backup** | ✅ Snapshots automatizados | Manual |
| **Costo Mensual** | $150-300 USD | $80-150 USD |
| **Recomendado para** | Producción, > 1000 usuarios | Desarrollo, MVP |

---

## Estimación de Costos en OCI (Región Ashburn)

### Opción OKE (Kubernetes)
- **Cluster OKE**: $0.10/hora x 3 nodos = **$216/mes**
- **Load Balancer Flexible**: **$25/mes** + bandwidth
- **Block Volumes**: 50GB x 2 = **$10/mes**
- **File Storage Service**: 100GB = **$3/mes**
- **Egress Bandwidth**: ~1TB = **$85/mes**
- **Total estimado**: **~$340/mes**

### Opción Compute
- **Compute Instances** (VM.Standard.E4.Flex): 2 OCPU x 4 instancias = **$120/mes**
- **Load Balancer Flexible**: **$25/mes**
- **Block Volumes**: 100GB = **$10/mes**
- **Egress Bandwidth**: ~500GB = **$43/mes**
- **Total estimado**: **~$200/mes**

---

## Recomendación Final

**Para Producción**: Usar **OKE (Kubernetes)** por:
- Escalado automático basado en métricas
- Alta disponibilidad nativa
- Rolling updates sin downtime
- Mejor gestión de configuración
- Monitoreo integrado

**Para Pruebas/MVP**: Usar **Compute + Docker** por:
- Setup más rápido
- Menor complejidad
- Costo reducido
- Más control directo

**Próximos Pasos**:
1. Crear cuenta OCI (Free Tier disponible)
2. Configurar VCN y Subnets
3. Elegir opción (OKE o Compute)
4. Seguir guía de despliegue correspondiente
5. Configurar DNS y SSL
6. Migrar datos de desarrollo a producción
