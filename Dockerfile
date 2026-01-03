# Usamos una imagen base ligera de Python 3.10
FROM python:3.10-slim

# Evita que Python genere archivos .pyc y permite ver logs en tiempo real
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Instalamos postgresql-client para poder usar el comando pg_isready
RUN apt-get update && apt-get install -y \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Definimos el directorio de trabajo dentro del contenedor
WORKDIR /app

# Copiamos las dependencias e instalamos
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copiamos los scripts de poblado y el entrypoint
COPY scripts/ ./scripts/
COPY entrypoint.sh .

# Hacemos el script de entrada ejecutable
RUN chmod +x entrypoint.sh

# Definimos el punto de entrada
ENTRYPOINT ["./entrypoint.sh"]
