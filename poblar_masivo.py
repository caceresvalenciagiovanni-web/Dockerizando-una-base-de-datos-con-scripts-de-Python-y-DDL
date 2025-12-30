import psycopg2
import time
import os
import psutil
import random
import io
from faker import Faker
from datetime import datetime, timedelta

# --- CONFIGURACIÓN ---
DB_CONFIG = {
    'dbname': 'hospital_db',
    'user': 'postgres',
    'password': 'tu_password_aqui',  # <--- COLOCA TU PASSWORD
    'host': 'localhost',
    'port': '5432'
}

fake = Faker('es_MX')

# Volúmenes Nivel 3 (Masivo)
COUNTS = {
    'departments': 50, 
    'rooms': 500, 
    'doctors': 200,          
    'patients': 100000,      
    'appointments': 1000000, 
    'admissions': 200000     
}

def copy_from_stringio(conn, data_io, table):
    cur = conn.cursor()
    data_io.seek(0)
    try:
        cur.copy_expert(f"COPY {table} FROM STDIN WITH (FORMAT CSV, NULL 'NULL')", data_io)
    except Exception as e:
        print(f"Error en COPY de tabla {table}: {e}")
        raise e

def run_level_3():
    conn = psycopg2.connect(**DB_CONFIG)
    cur = conn.cursor()
    
    try:
        print("--- INICIO NIVEL 3: Carga Masiva (DEFINITIVO) ---")
        print("Limpiando base de datos...")
        cur.execute("TRUNCATE appointments, admissions, doctors, patients, rooms, departments RESTART IDENTITY CASCADE;")
        
        # ---------------------------------------------------------
        # 1. Departments
        # ---------------------------------------------------------
        print(f"Generando CSV Departments ({COUNTS['departments']})...")
        csv_file = io.StringIO()
        for i in range(COUNTS['departments']):
            raw_job = fake.job()[:50].replace(',', '') 
            name = f"Departamento {raw_job} {i}"
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
        # 3. Doctors (Fechas de contratación variadas)
        # ---------------------------------------------------------
        print(f"Generando CSV Doctors ({COUNTS['doctors']})...")
        csv_file = io.StringIO()
        used_licenses = set()
        
        for i in range(COUNTS['doctors']):
            fname = fake.first_name().replace(',', '')
            lname = fake.last_name().replace(',', '')
            
            lic = fake.bothify(text='LIC-#####')
            while lic in used_licenses:
                lic = fake.bothify(text='LIC-#####')
            used_licenses.add(lic)
            
            dept_id = random.randint(1, COUNTS['departments'])
            
            # Generamos fecha de contratación entre hace 10 años y hoy
            hire_date = fake.date_between(start_date='-10y', end_date='today')
            
            # Escribimos: id, first, last, license, hire_date, dept_id
            csv_file.write(f"{i+1},{fname},{lname},{lic},{hire_date},{dept_id}\n")
            
        copy_from_stringio(conn, csv_file, "doctors (doctor_id, first_name, last_name, license_number, hire_date, department_id)")

        # ---------------------------------------------------------
        # 4. Patients (Emails y Nombres Reales)
        # ---------------------------------------------------------
        print(f"Generando CSV Patients ({COUNTS['patients']})...")
        csv_file = io.StringIO()
        
        for i in range(COUNTS['patients']):
            fname = fake.first_name().replace(',', '')
            lname = fake.last_name().replace(',', '')
            dni = f"DNI-{i+10000}" 
            dob = fake.date_of_birth()
            gender = 'M' if i % 2 == 0 else 'F'
            
            # Generamos email simple basado en nombre
            email = f"{fname.lower()}.{lname.lower()}{i}@example.com"
            
            csv_file.write(f"{i+1},{dni},{fname},{lname},{dob},{gender},{email}\n")
            
        copy_from_stringio(conn, csv_file, "patients (patient_id, dni, first_name, last_name, birth_date, gender, email)")

        # ---------------------------------------------------------
        # 5. Appointments (Fechas Dinámicas Rápidas)
        # ---------------------------------------------------------
        print(f"Generando CSV Appointments ({COUNTS['appointments']})...")
        csv_file = io.StringIO()
        
        # Fecha base: 1 de Enero de este año
        base_date = datetime(2023, 1, 1, 8, 0, 0)
        
        for _ in range(COUNTS['appointments']):
            pid = random.randint(1, COUNTS['patients'])
            did = random.randint(1, COUNTS['doctors'])
            
            # Truco de velocidad: Sumar minutos aleatorios a la fecha base (0 a 365 días en minutos)
            # Esto es mucho más rápido que fake.date_time_this_year()
            random_minutes = random.randint(0, 525600) 
            appt_date = base_date + timedelta(minutes=random_minutes)
            
            status = random.choice(['Programada', 'Completada', 'Cancelada'])
            
            csv_file.write(f"{appt_date},{status},{pid},{did}\n")
            
        copy_from_stringio(conn, csv_file, "appointments (date_time, status, patient_id, doctor_id)")

        # ---------------------------------------------------------
        # 6. Admissions (Fechas Coherentes: Alta > Ingreso)
        # ---------------------------------------------------------
        print(f"Generando CSV Admissions ({COUNTS['admissions']})...")
        csv_file = io.StringIO()
        
        for _ in range(COUNTS['admissions']):
            pid = random.randint(1, COUNTS['patients'])
            rid = random.randint(1, COUNTS['rooms'])
            did = random.randint(1, COUNTS['doctors'])
            diagnosis = fake.sentence().replace(',', '')
            
            # Fecha de ingreso aleatoria
            random_days_start = random.randint(0, 300)
            adm_date = base_date + timedelta(days=random_days_start)
            
            # Fecha de alta: Entre 1 y 15 días después del ingreso
            stay_days = random.randint(1, 15)
            dis_date = adm_date + timedelta(days=stay_days)
            
            csv_file.write(f"{adm_date},{dis_date},{diagnosis},{pid},{rid},{did}\n")
            
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
    process = psutil.Process(os.getpid())
    start_time = time.time()
    
    run_level_3()
    
    end_time = time.time()
    end_mem = process.memory_info().rss / (1024 * 1024) # MB
    
    print(f"\n=== RESULTADOS NIVEL 3 (MASIVO) ===")
    print(f"Tiempo total: {end_time - start_time:.4f} seg")
    print(f"Uso de Memoria: {end_mem:.2f} MB")
