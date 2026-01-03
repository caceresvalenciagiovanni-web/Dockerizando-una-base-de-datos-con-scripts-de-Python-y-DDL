# Sistema de Gestión Hospitalaria - Dockerizado

Este proyecto despliega un entorno completo de base de datos para un Hospital, incluyendo PostgreSQL, una aplicación en Python para generar datos sintéticos masivos y pgAdmin 4 para la administración visual. Todo orquestado con Docker.

## 📋 Características
* **Base de Datos Relacional:** PostgreSQL 15.
* **Modelo de Datos:** 6 Tablas (Departamentos, Médicos, Pacientes, Habitaciones, Citas, Admisiones) con integridad referencial completa.
* **Generación de Datos:** Scripts en Python (usando `Faker`) para poblar la BD en 3 niveles de volumen.
* **Interfaz Gráfica:** pgAdmin 4 integrado vía web.

---

## 🚀 Pre-requisitos

* **Docker Desktop** instalado y corriendo (Linux, Windows o desde un Macintosh).
* No es necesario tener instalado Python ni PostgreSQL en tu máquina local.

---

## 🛠️ Instalación y Despliegue

1. **Descargar y Descomprimir:**
   Descarga el archivo `.zip` y extrae el contenido. Abre una terminal dentro de la carpeta extraída (donde está el archivo `docker-compose.yml`).

2. **Levantar los Contenedores:**
   Ejecuta el siguiente comando para construir las imágenes e iniciar los servicios:
   ```bash
   docker compose up --build -d
   ```
Esto iniciará PostgreSQL, pgAdmin y el contenedor de la aplicación Python en segundo plano.

3. **Verificar Estado: Asegúrate de que los contenedores estén activos:
```bash
docker ps
``` 
Deberías ver 3 contenedores: hospital_db, hospital_pgadmin y hospital_poblador.

## 🧪 Poblar la Base de Datos
El sistema incluye scripts para generar datos. Elige el nivel de volumen que desees y ejecuta el comando correspondiente en tu terminal:

Opción A: Nivel Leve (~200 registros)
Ideal para pruebas rápidas y verificar integridad.
```bash
docker exec -it hospital_poblador python scripts/poblar_leve.py
```
Opción B: Nivel Moderado (~20,000 registros)
Usa inserción por lotes (Batch).
```bash
docker exec -it hospital_poblador python scripts/poblar_moderado.py
```
Opción C: Nivel Masivo (~1.3 Millones de registros)
Usa el método COPY para alta velocidad. (Recomendado)
```bash
docker exec -it hospital_poblador python scripts/poblar_masivo.py
```
## 📊 Acceso y Visualización (pgAdmin 4)
Para ver los datos gráficamente:

Abre tu navegador y ve a: http://localhost:5050

Iniciar Sesión en pgAdmin:

Email: admin@hospital.com

Password: admin

Conectar al Servidor (IMPORTANTE): Haz clic en "Add New Server" y configura lo siguiente:

Pestaña General > Name: Hospital Docker

Pestaña Connection:

Host name/address: db (⚠️ No usar localhost)

Port: 5432

Username: postgres

Password: tu_password_seguro (O la que esté en docker-compose.yml)

Guarda y explora las tablas en: Servers > Hospital Docker > Databases > hospital_db > Schemas > public > Tables.

## 🛑 Detener el sistema
Para apagar los contenedores conservando los datos:
```bash
docker compose stop
```
Para apagar y borrar los contenedores (los datos persisten en el volumen):
```bash
docker compose down
```
Para borrar todo (incluyendo la base de datos y su volumen):
```bash
docker compose down -v
```
