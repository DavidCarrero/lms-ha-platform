Contenerizar Moodle (PHP) con MariaDB

Archivos añadidos:
- Dockerfile
- docker-compose.yml
- .dockerignore

Instrucciones rápidas:

1) Construir y levantar los contenedores:

```powershell
docker-compose up -d --build
```

2) Abrir el navegador en `http://localhost:8080` y seguir el instalador web de Moodle. Use estos datos para la base de datos cuando el instalador pida conexión:

- Host: `db`
- Nombre BD: `moodle`
- Usuario: `moodle`
- Contraseña: `moodle`

3) Volúmenes:
- El código fuente del repositorio se monta en `/var/www/html`.
- Los datos de Moodle deben residir en el volumen `moodledata` (ya configurado en `docker-compose.yml`).

Notas y recomendaciones:
- Si encuentra errores de permisos, ejecute en la máquina host:

```powershell
docker-compose exec web chown -R www-data:www-data /var/www/html /var/moodledata
```

- Puede personalizar contraseñas en `docker-compose.yml` antes de levantar los contenedores.
- Para ejecutar tareas cron/CLI de Moodle use: `docker-compose exec web php admin/cli/cron.php`.
