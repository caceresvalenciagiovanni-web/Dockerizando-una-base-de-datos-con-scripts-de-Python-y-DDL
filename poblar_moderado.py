import psycopg2
import time
import os
import psutil
import random
import io
from faker import Faker

# --- CONFIGURACIÓN ---
DB_CONFIG = {
    'dbname': 'hospital_db',
    'user': 'postgres',
    'password': 'tu_password_aqui',  # <--- NO OLVIDES PONER TU CONTRASEÑA
    'host': 'localhost',
    'port': '5432'
}

# Inicializamos Faker
fake = Faker('es_MX')

# Volúmenes Nivel 3 (Masivo)
COUNTS = {
    'departments': 50, 
    'rooms': 500, 
    'doctors': 200,          # 200 Médicos
    'patients': 100000,      # 100k Pacientes
    'appointments': 1000000, # 1 Millón de Citas
    'admissions': 200000     # 200k Admisiones
}

def copy_from_stringio(conn, data_io, table):
    """
    Función auxiliar para empujar datos usando COPY desde un buffer en memoria.
    """
    cur = conn.cursor()
    data_io.seek(0)
    try:
        cur.copy_expert(f"COPY {table} FROM STDIN WITH (FORMAT CSV)", data_io)
    except Exception as e:
        print(f"Error en COPY de tabla {table}: {e}")
        raise e

def run_level_3():
    conn = psycopg2.connect(**DB_CONFIG)
    cur = conn.cursor()
    
    try:
        print("--- INICIO NIVEL 3: Carga Masiva ---")
        print("Limpiando base de datos...")
        cur.execute("TRUNCATE appointments, admissions, doctors, patients, rooms, departments RESTART IDENTITY CASCADE;")
        
        # ---------------------------------------------------------
        # 1. Departments
        # ---------------------------------------------------------
        print(f"Generando CSV Departments ({COUNTS['departments']})...")
        csv_file = io.StringIO()
        for i in range(COUNTS['departments']):
            # id, name, location, active
            # Usamos un nombre base + número para garantizar unicidad sin fallos
            name = f"Departamento {fake.job()[:50]} {i}"
            loc = f"Edificio {chr(65 + (i%5))}"
            csv_file.write(f"{i+1},{name},{loc},True\n")
        copy_from_stringio(conn, csv_file, "departments (department_id, name, location, is_active)")

        # ---------------------------------------------------------
        # 2. Rooms
        # ---------------------------------------------------------
        print(f"Generando CSV Rooms ({COUNTS['rooms']})...")
        csv_file = io.StringIO()
        types = ['General', 'UCI', 'Privada']
        for i in range(COUNTS['rooms']):
            r_num = f"H-{i+100}"
            r_type = random.choice(types)
            rate = round(random.uniform(50, 500), 2)
            csv_file.write(f"{i+1},{r_num},{r_type},{rate}\n")
        copy_from_stringio(conn, csv_file, "rooms (room_id, room_number, room_type, daily_rate)")
        
        # ---------------------------------------------------------
        # 3. Doctors (¡AHORA CON DATOS REALISTAS!)
        # ---------------------------------------------------------
        print(f"Generando CSV Doctors ({COUNTS['doctors']})...")
        csv_file = io.StringIO()
        used_licenses = set()
        
        for i in range(COUNTS['doctors']):
            fname = fake.first_name()
            lname = fake.last_name()
            
            # Generar licencia única
            lic = fake.bothify(text='LIC-#####')
            while lic in used_licenses:
                lic = fake.bothify(text='LIC-#####')
            used_licenses.add(lic)
            
            dept_id = random.randint(1, COUNTS['departments'])
            
            # Escribimos: id, first, last, license, dept_id
            csv_file.write(f"{i+1},{fname},{lname},{lic},{dept_id}\n")
            
        copy_from_stringio(conn, csv_file, "doctors (doctor_id, first_name, last_name, license_number, department_id)")

        # ---------------------------------------------------------
        # 4. Patients (¡AHORA CON DATOS REALISTAS!)
        # ---------------------------------------------------------
        print(f"Generando CSV Patients ({COUNTS['patients']}) - Esto tardará unos segundos por el realismo...")
        csv_file = io.StringIO()
        
        # Pre-calculamos IDs de pacientes para no usar lógica compleja dentro del loop
        # Usamos un loop simple. Faker puede ser lento x 100,000, ten paciencia.
        for i in range(COUNTS['patients']):
            fname = fake.first_name()
            lname = fake.last_name()
            dni = f"DNI-{i+10000}" # DNI secuencial simple para velocidad y unicidad
            dob = fake.date_of_birth()
            gender = 'M' if i % 2 == 0 else 'F'
            
            csv_file.write(f"{i+1},{dni},{fname},{lname},{dob},{gender}\n")
            
        copy_from_stringio(conn, csv_file, "patients (patient_id, dni, first_name, last_name, birth_date, gender)")

        # ---------------------------------------------------------
        # 5. Appointments (1 Millón)
        # ---------------------------------------------------------
        print(f"Generando CSV Appointments ({COUNTS['appointments']})...")
        csv_file = io.StringIO()
        # Aquí seguimos usando lógica rápida porque generar 1 millón de fechas random con Faker es muy lento
        # Usamos strings formateados directamente
        for _ in range(COUNTS['appointments']):
            pid = random.randint(1, COUNTS['patients'])
            did = random.randint(1, COUNTS['doctors'])
            # Fecha fija variada ligeramente o estática para velocidad extrema
            # Para masivo, a veces es mejor repetir fechas que calcularlas una por una
            csv_file.write(f"2023-05-20 10:00:00,Programada,{pid},{did}\n")
            
        copy_from_stringio(conn, csv_file, "appointments (date_time, status, patient_id, doctor_id)")

        # ---------------------------------------------------------
        # 6. Admissions
        # ---------------------------------------------------------
        print(f"Generando CSV Admissions ({COUNTS['admissions']})...")
        csv_file = io.StringIO()
        for _ in range(COUNTS['admissions']):
            pid = random.randint(1, COUNTS['patients'])
            rid = random.randint(1, COUNTS['rooms'])
            did = random.randint(1, COUNTS['doctors'])
            csv_file.write(f"2023-06-01 08:00:00,2023-06-05 18:00:00,Observación,{pid},{rid},{did}\n")
            
        copy_from_stringio(conn, csv_file, "admissions (admission_date, discharge_date, diagnosis, patient_id, room_id, doctor_id)")

        conn.commit()
        print("--- CARGA MASIVA EXITOSA ---")

    except Exception as e:
        if conn:
            conn.rollback()
        print(f"Error Crítico: {e}")
    finally:
        if conn:
            conn.close()

if __name__ == "__main__":
    # Medición de rendimiento
    process = psutil.Process(os.getpid())
    start_time = time.time()
    
    run_level_3()
    
    end_time = time.time()
    end_mem = process.memory_info().rss / (1024 * 1024) # MB
    
    print(f"\n=== RESULTADOS NIVEL 3 (MASIVO) ===")
    print(f"Tiempo total: {end_time - start_time:.4f} seg")
    print(f"Uso de Memoria: {end_mem:.2f} MB")
