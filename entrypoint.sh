#!/bin/bash
set -e

# Configuración de variables (valores por defecto)
DB_HOST=${DB_HOST:-db}
DB_PORT=${DB_PORT:-5432}
DB_USER=${DB_USER:-postgres}

echo "--- Esperando a que la base de datos PostgreSQL ($DB_HOST:$DB_PORT) esté lista... ---"

# Bucle de espera usando pg_isready
until pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER"; do
  echo "Base de datos no disponible aún - esperando 2 segundos..."
  sleep 2
done

echo "--- ¡Base de datos disponible! ---"

echo "--- Iniciando proceso de poblado. Nivel seleccionado: ${NIVEL_POBLADO:-leve} ---"

# Lógica de selección de nivel
case "$NIVEL_POBLADO" in
  "moderado")
    echo "Ejecutando script de poblado MODERADO..."
    python scripts/poblar_moderado.py
    ;;
  "masivo")
    echo "Ejecutando script de poblado MASIVO..."
    python scripts/poblar_masivo.py
    ;;
  *)
    echo "Nivel no definido o 'leve'. Ejecutando script de poblado LEVE..."
    python scripts/poblar_leve.py
    ;;
esac

echo "--- Proceso de poblado finalizado. Contenedor activo para monitoreo. ---"

# Mantiene el contenedor vivo si se pasan comandos extra, o finaliza limpiamente
exec "$@"
