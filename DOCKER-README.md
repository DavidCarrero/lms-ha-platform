# Moodle Docker - Guía de Uso

## 🚀 Versiones Actuales

- **PHP**: 8.3.29 con Apache 2.4.65
- **MariaDB**: 11.7.2 LTS
- **Moodle**: World's Open Source Learning Platform

## 📦 Servicios

### Base de Datos (moodle-db)
- **Imagen**: mariadb:11.7
- **Puerto interno**: 3306
- **Credenciales**:
  - Root: `root` / `rootpass`
  - Usuario: `moodle` / `moodle`
  - Base de datos: `moodle`
- **Auto-upgrade**: Habilitado

### Aplicación Web (moodle-web)
- **Imagen**: moodle-web:latest (2.33 GB)
- **Puerto**: 8080 → 80
- **Volúmenes**:
  - Código fuente: `./` → `/var/www/html`
  - Datos Moodle: `moodledata` → `/var/moodledata`

## 🛠️ Comandos Principales

### Iniciar servicios
```powershell
docker compose up -d
```

### Verificar estado
```powershell
docker compose ps
docker ps
```

### Ver logs
```powershell
# Todos los servicios
docker compose logs -f

# Solo la aplicación web
docker logs -f moodle-web

# Solo la base de datos
docker logs -f moodle-db
```

### Detener servicios
```powershell
docker compose down
```

### Detener y eliminar volúmenes (⚠️ Elimina datos)
```powershell
docker compose down -v
```

### Reconstruir la imagen web
```powershell
docker compose build --no-cache web
docker compose up -d
```

## 🌐 Acceso a la Aplicación

- **URL**: http://localhost:8080
- **Instalación inicial**: La primera vez que accedas, Moodle te guiará por el proceso de instalación

### Configuración de instalación sugerida:
- **Tipo de base de datos**: MariaDB/MySQL (Native)
- **Host**: `db`
- **Nombre de la BD**: `moodle`
- **Usuario**: `moodle`
- **Contraseña**: `moodle`

## 🔧 Solución de Problemas

### Error "Permission denied" en config.php
**Síntoma**: "Failed to open stream: Permission denied in /var/www/html/index.php"

**Causa**: El archivo `config.php` tiene permisos incorrectos (propiedad de root en lugar de www-data)

**Solución**:
```powershell
docker exec moodle-web chown www-data:www-data /var/www/html/config.php
docker exec moodle-web chmod 644 /var/www/html/config.php
```

### Error "Moodle root directory must not be publicly accessible"
**Síntoma**: "Please reconfigure your web server to use the `/public` directory instead"

**Causa**: Versiones recientes de Moodle requieren que Apache apunte a `/public` por seguridad

**Solución**: Ya está configurado en el Dockerfile actual. Si ves este error, reconstruye la imagen:
```powershell
docker compose build --no-cache web
docker compose up -d
```

### El contenedor de BD no arranca
```powershell
# Ver logs detallados
docker logs moodle-db

# Reiniciar con auto-upgrade
docker compose down
docker compose up -d
```

### Problemas de permisos generales
```powershell
# Ajustar permisos de todo el código
docker exec -it moodle-web chown -R www-data:www-data /var/www/html

# Ajustar permisos del directorio de datos
docker exec -it moodle-web chown -R www-data:www-data /var/moodledata
```

### La aplicación no carga
```powershell
# Verificar que Apache esté corriendo
docker exec moodle-web apache2ctl status

# Verificar configuración de Apache
docker exec moodle-web apache2ctl -S

# Reiniciar el contenedor web
docker restart moodle-web
```

## 📊 Verificar Servicios

### Conectar a la base de datos
```powershell
docker exec -it moodle-db mariadb -u moodle -pmoodle
```

### Acceder al contenedor web
```powershell
docker exec -it moodle-web bash
```

## 🔐 Seguridad

⚠️ **IMPORTANTE**: Las contraseñas predeterminadas son para desarrollo. En producción:
1. Cambia todas las contraseñas
2. Usa variables de entorno o secrets
3. Configura SSL/HTTPS
4. Restringe el acceso a puertos

## 📝 Estructura de Volúmenes

- `db_data`: Datos persistentes de MariaDB
- `moodledata`: Archivos y datos de Moodle
- `./`: Código fuente montado en tiempo real (desarrollo)

## 🔄 Actualizar Versiones

El archivo `docker-compose.yml` está configurado con las últimas versiones estables. Para actualizar:

```powershell
docker compose pull
docker compose up -d
```

## 📚 Recursos Adicionales

- [Documentación de Moodle](https://docs.moodle.org/)
- [Moodle.org](https://moodle.org/)
- [MariaDB Documentation](https://mariadb.com/kb/en/documentation/)
- [PHP 8.3 Documentation](https://www.php.net/manual/en/)
