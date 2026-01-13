# 📦 Guía Completa de Contenerización de Moodle

## 🎯 Descripción del Proyecto

Contenedor Docker completo y funcional para **Moodle 5.2dev** (World's Open Source Learning Platform) con todas las dependencias, extensiones PHP requeridas y configuraciones óptimas para entornos de desarrollo y producción.

---

## 📋 Tabla de Contenidos

1. [Versiones de Software](#versiones-de-software)
2. [Arquitectura del Proyecto](#arquitectura-del-proyecto)
3. [Paquetes y Dependencias](#paquetes-y-dependencias)
4. [Configuraciones Aplicadas](#configuraciones-aplicadas)
5. [Errores Corregidos](#errores-corregidos)
6. [Comandos de Uso](#comandos-de-uso)
7. [Troubleshooting](#troubleshooting)

---

## 🚀 Versiones de Software

### Contenedor Web (moodle-web)
- **Imagen Base**: `php:8.3-apache`
- **PHP**: 8.3.29
- **Apache**: 2.4.65 (Debian)
- **Composer**: Latest (integrado desde imagen oficial)
- **Moodle**: 5.2dev (Build: 20260109)

### Contenedor Base de Datos (moodle-db)
- **MariaDB**: 11.7.2 LTS (ubu2404)
- **Usuario**: moodle
- **Base de Datos**: moodle
- **Puerto**: 3306 (interno)

---

## 🏗️ Arquitectura del Proyecto

```
┌─────────────────────────────────────────────────────────┐
│                    Docker Compose                       │
│                                                          │
│  ┌──────────────────┐         ┌──────────────────────┐ │
│  │   moodle-web     │◄────────┤    moodle-db         │ │
│  │  (PHP + Apache)  │         │  (MariaDB 11.7.2)    │ │
│  │  Puerto: 8080    │         │  Puerto: 3306        │ │
│  └──────────────────┘         └──────────────────────┘ │
│         │                              │                │
│         ▼                              ▼                │
│  ┌──────────────────┐         ┌──────────────────────┐ │
│  │  Volume: ./      │         │  Volume: db_data     │ │
│  │  (código fuente) │         │  (datos persistentes)│ │
│  └──────────────────┘         └──────────────────────┘ │
│         │                                               │
│         ▼                                               │
│  ┌──────────────────┐                                  │
│  │ Volume:          │                                  │
│  │ moodledata       │                                  │
│  └──────────────────┘                                  │
└─────────────────────────────────────────────────────────┘
```

---

## 📦 Paquetes y Dependencias

### 1. **Dependencias del Sistema (apt)**

```dockerfile
libpng-dev          # Requerido para gd (procesamiento de imágenes)
libjpeg62-turbo-dev # Soporte JPEG para gd
libfreetype6-dev    # Soporte de fuentes para gd
libzip-dev          # Manejo de archivos ZIP
zip / unzip         # Herramientas de compresión
git                 # Control de versiones
libicu-dev          # Internacionalización (i18n)
libxml2-dev         # Procesamiento XML (requerido para soap)
zlib1g-dev          # Compresión de datos
libonig-dev         # Expresiones regulares multibyte
```

**Para qué sirven:**
- **libpng, libjpeg, libfreetype**: Permiten a PHP procesar y manipular imágenes (avatares, logos, gráficos)
- **libzip**: Moodle usa ZIP para backup, restauración y empaquetado de recursos
- **libicu**: Soporte multi-idioma completo (más de 100 idiomas en Moodle)
- **libxml2**: Requerido para SOAP (web services) y parsing XML de configuraciones

### 2. **Extensiones PHP Instaladas**

#### ✅ **Extensiones Obligatorias**
```php
gd              # Procesamiento de imágenes (avatares, thumbnails, gráficos)
intl            # Internacionalización completa (formato fechas, números, monedas)
mbstring        # Soporte multibyte strings (UTF-8, emojis, caracteres especiales)
xml             # Parsing y generación de XML
zip             # Compresión/descompresión de archivos
pdo_mysql       # Driver PDO para MySQL/MariaDB (abstracción de BD)
mysqli          # Driver nativo MySQL mejorado
opcache         # Cache de bytecode PHP (mejora performance 30-50%)
```

#### 🔧 **Extensiones Opcionales (pero recomendadas)**
```php
soap            # Web services SOAP (integración con sistemas externos)
exif            # Lectura de metadatos de imágenes (orientación, fecha, cámara)
```

**Detalles de cada extensión:**

| Extensión | Propósito | Ejemplo de Uso |
|-----------|-----------|----------------|
| **gd** | Redimensionar, recortar, agregar marcas de agua a imágenes | Crear thumbnails de perfiles de usuario |
| **intl** | Formatear fechas, números, ordenar strings según idioma | "15 de Enero de 2026" vs "January 15, 2026" |
| **mbstring** | Manejar caracteres multi-byte (UTF-8) | Nombres con ñ, ü, emojis 😀 |
| **xml** | Procesar archivos de configuración y datos | Importar/exportar calificaciones en XML |
| **zip** | Empaquetar cursos completos para backup | Descargar curso como .zip |
| **pdo_mysql** | Conectar a BD usando PDO (más seguro) | Queries parametrizadas anti-SQL injection |
| **mysqli** | Conectar a BD con funciones nativas | Operaciones de BD específicas de MySQL |
| **opcache** | Cachear código PHP compilado en memoria | Reducir tiempo de carga de páginas |
| **soap** | Comunicación con servicios web externos | Integrar con sistema de matrícula |
| **exif** | Rotar imágenes automáticamente | Corregir orientación de fotos de celular |

### 3. **Composer y Dependencias PHP**

```bash
composer install --no-dev --no-interaction --optimize-autoloader --classmap-authoritative
```

**Flags explicados:**
- `--no-dev`: No instala dependencias de desarrollo (testing, debugging)
- `--no-interaction`: Modo no interactivo (perfecto para CI/CD)
- `--optimize-autoloader`: Genera mapa optimizado de clases (mejora carga)
- `--classmap-authoritative`: Usa SOLO el classmap (más rápido en producción)

**Para qué sirve:**
- Instala ~50-70 paquetes PHP que Moodle usa internacionalmente
- Librerías comunes: PHPMailer, Guzzle, Monolog, etc.
- Sin esto, muchas funcionalidades NO funcionarán

---

## ⚙️ Configuraciones Aplicadas

### 1. **Configuración PHP (moodle.ini)**

```ini
memory_limit = 512M                  # Memoria máxima por script PHP
upload_max_filesize = 100M           # Tamaño máximo de archivo subido
post_max_size = 100M                 # Tamaño máximo de POST request
max_input_vars = 5000                # Variables máximas en formularios
max_execution_time = 300             # Tiempo máximo de ejecución (5 min)
opcache.enable = 1                   # Activar cache de código
opcache.memory_consumption = 128     # RAM para opcache (128MB)
opcache.max_accelerated_files = 10000 # Archivos PHP cacheables
zend.exception_ignore_args = On      # Seguridad: ocultar args en excepciones
```

**Por qué estos valores:**

| Configuración | Valor Default PHP | Valor Moodle | Razón |
|---------------|-------------------|--------------|-------|
| `memory_limit` | 128M | **512M** | Moodle procesa muchos datos simultáneos (calificaciones, reportes) |
| `upload_max_filesize` | 2M | **100M** | Permitir subir videos, PDFs grandes, presentaciones |
| `max_input_vars` | 1000 | **5000** | Formularios grandes (quiz con 100+ preguntas) |
| `max_execution_time` | 30 | **300** | Operaciones largas (backup de curso, generación de reportes) |
| `opcache.max_accelerated_files` | 2000 | **10000** | Moodle tiene ~8000 archivos PHP |
| `zend.exception_ignore_args` | Off | **On** | **Seguridad**: No mostrar contraseñas/tokens en stack traces |

### 2. **Configuración Apache (VirtualHost)**

```apache
DocumentRoot /var/www/html/public   # Apuntar a /public NO a /
<Directory /var/www/html/public>
    Options Indexes FollowSymLinks
    AllowOverride All               # Permitir .htaccess
    Require all granted
</Directory>
```

**Mejora de Seguridad:**
- Moodle moderno (5.x) requiere que Apache apunte a `/public`
- Archivos sensibles (config.php, cron.php) NO son accesibles vía web
- Solo archivos en `/public` son servidos por Apache

### 3. **Configuración Base de Datos (config.php)**

```php
$CFG->dbtype    = 'mariadb';  // IMPORTANTE: NO 'mysqli'
$CFG->dblibrary = 'native';
$CFG->dbhost    = 'db';        // Nombre del servicio en docker-compose
```

**¿Por qué 'mariadb' y no 'mysqli'?**
- `mysqli` = Driver genérico MySQL
- `mariadb` = Driver optimizado para MariaDB 10.x y 11.x
- Mejor performance, soporte de nuevas features de MariaDB

### 4. **MariaDB - Auto-Upgrade**

```yaml
environment:
  MARIADB_AUTO_UPGRADE: "1"
```

**Para qué sirve:**
- Al actualizar de MariaDB 10.x → 11.x, ejecuta `mariadb-upgrade` automáticamente
- Actualiza tablas del sistema, permisos, vistas
- Sin esto, Moodle puede fallar al conectarse tras una actualización

---

## 🐛 Errores Corregidos

### **Error 1: Wrong $CFG->dbtype 'mysqli'**
**Síntoma:**
```
Wrong $CFG->dbtype. You need to change it in your config.php file from 'mysqli' to 'mariadb'.
```

**Causa:** Moodle 5.x detecta MariaDB 11.x y requiere driver específico

**Solución:**
```php
// ANTES
$CFG->dbtype = 'mysqli';

// DESPUÉS
$CFG->dbtype = 'mariadb';
```

---

### **Error 2: Extension 'soap' not installed**
**Síntoma:**
```
soap should be installed and enabled for best results
Installing the optional SOAP extension is useful for web services and some plugins.
```

**Causa:** SOAP no venía incluido en PHP base

**Solución en Dockerfile:**
```dockerfile
RUN docker-php-ext-install -j$(nproc) \
    gd intl mbstring xml zip pdo_mysql mysqli opcache soap exif
```

**Para qué se usa SOAP en Moodle:**
- Integración con sistemas de matrícula externos
- Sincronización con Active Directory / LDAP
- Web services para apps móviles

---

### **Error 3: Extension 'exif' not installed**
**Síntoma:**
```
exif should be installed and enabled for best results
```

**Causa:** No venía en PHP base

**Solución:**
```dockerfile
RUN docker-php-ext-install ... exif
```

**Para qué se usa:**
- Auto-rotar imágenes según metadatos EXIF
- Usuarios suben fotos desde celular → Moodle las rota correctamente

---

### **Error 4: zend.exception_ignore_args debe estar On**
**Síntoma:**
```
It is strongly recommended that the PHP setting zend.exception_ignore_args be enabled as a security precaution.
```

**Riesgo de seguridad:**
```php
// Sin zend.exception_ignore_args=On
throw new Exception("Login failed for user: $username with password: $password");
// Stack trace mostraría la contraseña! 🚨
```

**Solución:**
```ini
zend.exception_ignore_args = On
```

---

### **Error 5: max_input_vars too low (< 5000)**
**Síntoma:**
```
PHP setting max_input_vars must be at least 5000.
```

**Problema:**
- Formularios grandes (quiz con 50 preguntas = 200-500 inputs)
- PHP trunca datos si excede max_input_vars
- Resultante: pérdida de respuestas del estudiante

**Solución:**
```ini
max_input_vars = 5000
```

---

### **Error 6: Composer vendor directory not found**
**Síntoma:**
```
Composer dependencies were not found. Make sure "composer install --no-dev" has been run.
```

**Causa:** Moodle usa ~60 librerías PHP externas vía Composer

**Solución en Dockerfile:**
```dockerfile
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer
RUN composer install --no-dev --no-interaction --optimize-autoloader
```

---

### **Error 7: Site not HTTPS**
**Síntoma:**
```
It has been detected that your site is not secured using HTTPS.
```

**Nota:** Este es un WARNING para producción. En desarrollo (localhost) es aceptable.

**Solución para producción:**
1. Configurar nginx/traefik como reverse proxy con SSL
2. Usar Let's Encrypt para certificado gratuito
3. Actualizar `$CFG->wwwroot` a `https://`

---

## 📝 Comandos de Uso

### Iniciar/Detener Servicios

```powershell
# Iniciar (primera vez o tras cambios)
docker compose up -d --build

# Iniciar (sin reconstruir)
docker compose up -d

# Detener
docker compose down

# Detener y eliminar volúmenes (⚠️ ELIMINA DATOS)
docker compose down -v
```

### Ver Logs

```powershell
# Logs de ambos contenedores (seguimiento en tiempo real)
docker compose logs -f

# Solo logs del servidor web
docker logs -f moodle-web

# Solo logs de la BD
docker logs -f moodle-db

# Últimas 100 líneas
docker logs --tail 100 moodle-web
```

### Acceder a los Contenedores

```powershell
# Shell en el contenedor web
docker exec -it moodle-web bash

# Shell en MariaDB
docker exec -it moodle-db bash

# Cliente MariaDB directo
docker exec -it moodle-db mariadb -u moodle -pmoodle
```

### Verificar Configuraciones

```powershell
# Ver versión de PHP y extensiones instaladas
docker exec moodle-web php -v
docker exec moodle-web php -m

# Ver configuración PHP específica
docker exec moodle-web php -i | grep "max_input_vars"

# Verificar que Composer instaló dependencias
docker exec moodle-web ls -la vendor/
```

### Backup y Restauración

```powershell
# Backup de la base de datos
docker exec moodle-db mariadb-dump -u moodle -pmoodle moodle > backup_$(Get-Date -Format "yyyyMMdd_HHmmss").sql

# Restaurar base de datos
Get-Content backup_20260112.sql | docker exec -i moodle-db mariadb -u moodle -pmoodle moodle

# Backup de moodledata (archivos subidos)
docker run --rm -v moddle_moodledata:/source -v ${PWD}:/backup ubuntu tar czf /backup/moodledata_backup.tar.gz -C /source .
```

---

## 🔧 Troubleshooting

### Problema: "Permission denied" en archivos

```powershell
# Corregir permisos dentro del contenedor
docker exec moodle-web chown -R www-data:www-data /var/www/html
docker exec moodle-web chown -R www-data:www-data /var/moodledata
```

### Problema: BD no arranca o unhealthy

```powershell
# Ver logs detallados
docker logs moodle-db

# Reiniciar solo la BD
docker restart moodle-db

# Verificar healthcheck
docker inspect moodle-db | grep -A 10 Health
```

### Problema: "Site is being upgraded"

Este mensaje es normal tras actualizaciones. Opciones:

1. Esperar a que termine (puede tomar 5-30 min)
2. Ver progreso: `docker logs -f moodle-web`
3. Si se cuelga: `docker restart moodle-web`

### Problema: Moodle muy lento

```powershell
# Verificar que opcache esté activo
docker exec moodle-web php -i | grep "opcache.enable"

# Limpiar caché de Moodle
docker exec moodle-web php admin/cli/purge_caches.php

# Reiniciar Apache
docker exec moodle-web apache2ctl graceful
```

### Problema: "Out of memory"

```powershell
# Ver memoria actual de PHP
docker exec moodle-web php -i | grep "memory_limit"

# Si necesitas más, edita Dockerfile y reconstruye:
# echo 'memory_limit = 1024M' >> /usr/local/etc/php/conf.d/moodle.ini
```

---

## 📊 Performance Tips

### 1. Producción: Usar volumen nombrado en lugar de bind mount

```yaml
# DESARROLLO (bind mount - cambios en tiempo real)
volumes:
  - ./:/var/www/html

# PRODUCCIÓN (volumen nombrado - más rápido)
volumes:
  - moodle_code:/var/www/html
```

**Diferencia de performance:** 30-50% más rápido en Windows/Mac

### 2. Aumentar recursos de Docker

Docker Desktop → Settings → Resources:
- **CPU**: Mínimo 2 cores, recomendado 4
- **RAM**: Mínimo 4GB, recomendado 8GB

### 3. Habilitar BuildKit para builds más rápidos

```powershell
# En PowerShell
$env:DOCKER_BUILDKIT=1
docker compose build
```

---

## 🌐 Acceso a la Aplicación

- **URL**: http://localhost:8080
- **Instalación Inicial**: Primera vez → seguir wizard de instalación
- **Credenciales BD**:
  - Host: `db`
  - Database: `moodle`
  - User: `moodle`
  - Password: `moodle`

---

## 📚 Recursos Adicionales

- [Documentación Oficial de Moodle](https://docs.moodle.org/)
- [Moodle.org - Comunidad](https://moodle.org/)
- [PHP Docker Official Images](https://hub.docker.com/_/php)
- [MariaDB Documentation](https://mariadb.com/kb/en/documentation/)

---

## 🎉 Conclusión

Este contenedor Docker incluye:
- ✅ PHP 8.3.29 con **TODAS** las extensiones requeridas y recomendadas
- ✅ MariaDB 11.7.2 LTS con auto-upgrade
- ✅ Composer con dependencias instaladas y optimizadas
- ✅ Configuración PHP optimizada para Moodle (memory, uploads, opcache)
- ✅ Apache configurado con `/public` como DocumentRoot (seguridad)
- ✅ Todos los errores del checker de Moodle corregidos

**Estado:** ✅ **Producción-ready** (con HTTPS configurado en reverse proxy)
