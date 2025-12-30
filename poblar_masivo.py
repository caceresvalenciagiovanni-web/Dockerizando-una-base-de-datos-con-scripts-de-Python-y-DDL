import psycopg2
import time
import os
import psutil
import random
import io
from faker import Faker

DB_CONFIG = {
    'dbname': 'hospital_db',
    'user': 'postgres',
    'password': 'tu_password_aqui', 
    'host': 'localhost',
    'port': '5432'
}
fake = Faker('es_MX')

# Volumen Masivo
COUNTS = {
    'departments': 50, 'rooms': 500, 'doctors': 200,
    'patients': 100000, 'appointments': 1000000, 'admissions': 200000
}

def copy_from_stringio(conn, data_io, table):
    cur = conn.cursor()
    data_io.seek(0)
    cur.copy_expert(f"COPY {table} FROM STDIN WITH (FORMAT CSV)", data_io)

def run_level_3():
    conn = psycopg2.connect(**DB_CONFIG)
    cur = conn.cursor()
    
    try:
        print("--- Limpiando BD y Reseteando Secuencias... ---")
        cur.execute("TRUNCATE appointments, admissions, doctors, patients, rooms, departments RESTART IDENTITY CASCADE;")
        
        # 1. Departments
        print("Generando CSV Departments...")
        csv_file = io.StringIO()
        for i in range(COUNTS['departments']):
            # id, name, location, active
            csv_file.write(f"{i+1},Dept-{i},Edificio-{i%5},True\n")
        copy_from_stringio(conn, csv_file, "departments (department_id, name, location, is_active)")

        # 2. Rooms
        print("Generando CSV Rooms...")
        csv_file = io.StringIO()
        for i in range(COUNTS['rooms']):
            csv_file.write(f"{i+1},RM-{i},General,150.00\n")
        copy_from_stringio(conn, csv_file, "rooms (room_id, room_number, room_type, daily_rate)")
        
        # 3. Doctors
        print("Generando CSV Doctors...")
        csv_file = io.StringIO()
        for i in range(COUNTS['doctors']):
            dept_id = random.randint(1, COUNTS['departments'])
            csv_file.write(f"{i+1},Dr,Apellido,LIC-{i},{dept_id}\n")
        copy_from_stringio(conn, csv_file, "doctors (doctor_id, first_name, last_name, license_number, department_id)")

        # 4. Patients (Optimización: datos estáticos para velocidad)
        print("Generando CSV Patients (Esto tomará unos segundos)...")
        csv_file = io.StringIO()
        for i in range(COUNTS['patients']):
            # id, dni, name, last, birth, gender
            csv_file.write(f"{i+1},DNI-{i},Nombre,Ape,2000-01-01,M\n")
        copy_from_stringio(conn, csv_file, "patients (patient_id, dni, first_name, last_name, birth_date, gender)")

        # 5. Appointments (El más pesado: 1 Millón)
        print("Generando CSV Appointments (1 Millón de filas)...")
        csv_file = io.StringIO()
        # Generar string masivo es costoso en RAM, lo hacemos por bloques si fuera necesario, 
        # pero 1M cabe en memoria moderna (aprox 50-100MB texto).
        for _ in range(COUNTS['appointments']):
            pid = random.randint(1, COUNTS['patients'])
            did = random.randint(1, COUNTS['doctors'])
            csv_file.write(f"2023-01-01 10:00:00,Programada,{pid},{did}\n")
        copy_from_stringio(conn, csv_file, "appointments (date_time, status, patient_id, doctor_id)")

        # 6. Admissions
        print("Generando CSV Admissions...")
        csv_file = io.StringIO()
        for _ in range(COUNTS['admissions']):
            pid = random.randint(1, COUNTS['patients'])
            rid = random.randint(1, COUNTS['rooms'])
            did = random.randint(1, COUNTS['doctors'])
            csv_file.write(f"2023-01-01,2023-01-05,Gripe,{pid},{rid},{did}\n")
        copy_from_stringio(conn, csv_file, "admissions (admission_date, discharge_date, diagnosis, patient_id, room_id, doctor_id)")

        conn.commit()
        print("--- Carga Masiva (COPY) Finalizada ---")

    except Exception as e:
        conn.rollback()
        print(f"Error Crítico: {e}")
    finally:
        conn.close()

if __name__ == "__main__":
    process = psutil.Process(os.getpid())
    start_time = time.time()
    
    run_level_3()
    
    end_time = time.time()
    end_mem = process.memory_info().rss / (1024 * 1024)
    
    print(f"\nResultados Nivel 3 (Masivo):")
    print(f"Tiempo ejecución: {end_time - start_time:.4f} seg")
    print(f"Uso Memoria: {end_mem:.2f} MB")
