# Sistema de Gestión Hospitalaria - Dockerizado

Este proyecto despliega una base de datos PostgreSQL y un set de scripts de Python para poblar datos sintéticos realistas en tres niveles de volumen.

## 1. Estructura del Proyecto
* **sql/ddl/**: Contiene el esquema de la base de datos (se ejecuta automáticamente al inicio).
* **scripts/**: Scripts de Python (Faker) para generar datos.
* **Dockerfile**: Definición de la imagen de la aplicación.
* **docker-compose.yml**: Orquestación de servicios.

## 2. Pre-requisitos
* Docker y Docker Compose instalados.
* (Opcional) Un cliente SQL como DBeaver para inspeccionar los datos.

## 3. Comandos de Ejecución

Para iniciar el sistema, elige el nivel de datos que deseas cargar configurando la variable de entorno.

### Nivel 1: Poblado Leve (Desarrollo - Default)
Carga ~200 registros. Ideal para pruebas rápidas.
```bash
docker exec -it hospital_poblador python scripts/poblar_leve.py
```

### Nivel 2: Poblado Moderado (Batch)
Carga ~20,000 registros usando inserción por lotes.
```bash
docker exec -it hospital_poblador python scripts/poblar_moderado.py
```
### Nivel 3: Poblado Masivo (COPY)
Carga ~1,300,000 registros usando buffers en memoria y COPY command.
```bash
docker exec -it hospital_poblador python scripts/poblar_masivo.py
```
### 4. Limpieza
Para borrar la base de datos y empezar de cero (incluyendo volúmenes):
```bash
docker-compose down -v
```
