import psycopg2
import time
import os
import psutil
import random
from faker import Faker
from datetime import timedelta

# --- CONFIGURACIÓN ---
DB_CONFIG = {
    'dbname': 'hospital_db',
    'user': 'postgres',
    'password': 'tu_password_aqui', 
    'host': 'localhost',
    'port': '5432'
}

fake = Faker('es_MX')

# Cantidades Nivel 1
COUNTS = {
    'departments': 10, 'rooms': 20, 'doctors': 15,
    'patients': 50, 'appointments': 100, 'admissions': 30
}

def run_level_1():
    conn = psycopg2.connect(**DB_CONFIG)
    cur = conn.cursor()
    
    # Listas para guardar IDs generados y mantener integridad referencial
    dept_ids, room_ids, doc_ids, pat_ids = [], [], [], []

    try:
        print("--- Limpiando base de datos... ---")
        cur.execute("TRUNCATE appointments, admissions, doctors, patients, rooms, departments RESTART IDENTITY CASCADE;")
        
        print("--- Iniciando Inserción Uno a Uno ---")
        
        # 1. Departments
        for _ in range(COUNTS['departments']):
            cur.execute("INSERT INTO departments (name, location) VALUES (%s, %s) RETURNING department_id", 
                        (fake.unique.job()[:90] + str(random.randint(1,999)), fake.building_number()))
            dept_ids.append(cur.fetchone()[0])

        # 2. Rooms
        types = ['General', 'UCI', 'Privada']
        for _ in range(COUNTS['rooms']):
            cur.execute("INSERT INTO rooms (room_number, room_type, daily_rate) VALUES (%s, %s, %s) RETURNING room_id",
                        (fake.unique.bothify('RM-###'), random.choice(types), random.uniform(50, 500)))
            room_ids.append(cur.fetchone()[0])

        # 3. Doctors
        for _ in range(COUNTS['doctors']):
            cur.execute("INSERT INTO doctors (first_name, last_name, license_number, department_id) VALUES (%s, %s, %s, %s) RETURNING doctor_id",
                        (fake.first_name(), fake.last_name(), fake.unique.bothify('LIC-#####'), random.choice(dept_ids)))
            doc_ids.append(cur.fetchone()[0])

        # 4. Patients
        for _ in range(COUNTS['patients']):
            cur.execute("INSERT INTO patients (dni, first_name, last_name, birth_date, gender) VALUES (%s, %s, %s, %s, %s) RETURNING patient_id",
                        (fake.unique.ssn(), fake.first_name(), fake.last_name(), fake.date_of_birth(), random.choice(['M', 'F'])))
            pat_ids.append(cur.fetchone()[0])

        # 5. Appointments
        for _ in range(COUNTS['appointments']):
            cur.execute("INSERT INTO appointments (date_time, status, patient_id, doctor_id) VALUES (%s, %s, %s, %s)",
                        (fake.date_time_this_year(), random.choice(['Programada', 'Completada']), random.choice(pat_ids), random.choice(doc_ids)))

        # 6. Admissions
        for _ in range(COUNTS['admissions']):
            d_in = fake.date_time_this_year()
            d_out = d_in + timedelta(days=random.randint(1,5))
            cur.execute("INSERT INTO admissions (admission_date, discharge_date, diagnosis, patient_id, room_id, doctor_id) VALUES (%s, %s, %s, %s, %s, %s)",
                        (d_in, d_out, fake.sentence(), random.choice(pat_ids), random.choice(room_ids), random.choice(doc_ids)))

        conn.commit()
        print("--- Commit realizado ---")

    except Exception as e:
        conn.rollback()
        print(f"Error: {e}")
    finally:
        conn.close()

if __name__ == "__main__":
    process = psutil.Process(os.getpid())
    start_mem = process.memory_info().rss / (1024 * 1024)
    start_time = time.time()

    run_level_1()

    end_time = time.time()
    end_mem = process.memory_info().rss / (1024 * 1024)

    print(f"\nResultados Nivel 1 (Leve):")
    print(f"Tiempo ejecución: {end_time - start_time:.4f} seg")
    print(f"Uso Memoria: {end_mem:.2f} MB")
