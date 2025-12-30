import psycopg2
import time
import os
import psutil
import random
from faker import Faker
from datetime import timedelta

DB_CONFIG = {
    'dbname': 'hospital_db',
    'user': 'postgres',
    'password': 'tu_password_aqui', 
    'host': 'localhost',
    'port': '5432'
}
fake = Faker('es_MX')

COUNTS = {
    'departments': 20, 'rooms': 100, 'doctors': 50,
    'patients': 5000, 'appointments': 15000, 'admissions': 2000
}

def run_level_2():
    conn = psycopg2.connect(**DB_CONFIG)
    cur = conn.cursor()
    
    try:
        print("--- Limpiando BD... ---")
        cur.execute("TRUNCATE appointments, admissions, doctors, patients, rooms, departments RESTART IDENTITY CASCADE;")
        
        print("--- Generando datos en memoria (Batch)... ---")
        
        # 1. Departments
        depts = [(fake.unique.job()[:90] + str(i), fake.building_number()) for i in range(COUNTS['departments'])]
        cur.executemany("INSERT INTO departments (name, location) VALUES (%s, %s)", depts)
        
        # 2. Rooms
        rooms = [(f"R-{i}", random.choice(['General', 'UCI']), random.uniform(50,500)) for i in range(COUNTS['rooms'])]
        cur.executemany("INSERT INTO rooms (room_number, room_type, daily_rate) VALUES (%s, %s, %s)", rooms)
        
        # 3. Doctors (Asumimos IDs secuenciales 1..20 para depts)
        docs = []
        for i in range(COUNTS['doctors']):
            docs.append((fake.first_name(), fake.last_name(), f"LIC-{i}", random.randint(1, COUNTS['departments'])))
        cur.executemany("INSERT INTO doctors (first_name, last_name, license_number, department_id) VALUES (%s, %s, %s, %s)", docs)
        
        # 4. Patients
        pats = []
        for i in range(COUNTS['patients']):
            pats.append((f"DNI-{i}", fake.first_name(), fake.last_name(), fake.date_of_birth(), random.choice(['M','F'])))
        cur.executemany("INSERT INTO patients (dni, first_name, last_name, birth_date, gender) VALUES (%s, %s, %s, %s, %s)", pats)

        print("--- Insertando Tablas Secundarias... ---")

        # 5. Appointments (Batch de 1000 en 1000 si fuera muy grande, aqui entra todo junto)
        apps = []
        for _ in range(COUNTS['appointments']):
            apps.append((fake.date_time_this_year(), 'Programada', random.randint(1, COUNTS['patients']), random.randint(1, COUNTS['doctors'])))
        cur.executemany("INSERT INTO appointments (date_time, status, patient_id, doctor_id) VALUES (%s, %s, %s, %s)", apps)

        # 6. Admissions
        adms = []
        for _ in range(COUNTS['admissions']):
            d = fake.date_time_this_year()
            adms.append((d, d+timedelta(days=2), 'Obs', random.randint(1, COUNTS['patients']), random.randint(1, COUNTS['rooms']), random.randint(1, COUNTS['doctors'])))
        cur.executemany("INSERT INTO admissions (admission_date, discharge_date, diagnosis, patient_id, room_id, doctor_id) VALUES (%s, %s, %s, %s, %s, %s)", adms)

        conn.commit()
        print("--- Batch insert finalizado ---")

    except Exception as e:
        conn.rollback()
        print(f"Error: {e}")
    finally:
        conn.close()

if __name__ == "__main__":
    process = psutil.Process(os.getpid())
    start_time = time.time()
    
    run_level_2()
    
    end_time = time.time()
    end_mem = process.memory_info().rss / (1024 * 1024)
    
    print(f"\nResultados Nivel 2 (Moderado):")
    print(f"Tiempo ejecución: {end_time - start_time:.4f} seg")
    print(f"Uso Memoria: {end_mem:.2f} MB")
