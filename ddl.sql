-- 1. Tabla Departments (Sin dependencias foráneas)
CREATE TABLE departments (
    department_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    location VARCHAR(50),
    is_active BOOLEAN DEFAULT TRUE
);

-- 2. Tabla Doctors (Depende de Departments)
CREATE TABLE doctors (
    doctor_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    license_number VARCHAR(20) NOT NULL UNIQUE,
    hire_date DATE DEFAULT CURRENT_DATE,
    department_id INT NOT NULL,
    -- FK: Relación con departments
    CONSTRAINT fk_doctor_dept FOREIGN KEY (department_id) 
        REFERENCES departments(department_id)
);

-- 3. Tabla Patients (Sin dependencias foráneas iniciales)
CREATE TABLE patients (
    patient_id SERIAL PRIMARY KEY,
    dni VARCHAR(20) NOT NULL UNIQUE,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    birth_date DATE NOT NULL,
    gender CHAR(1),
    email VARCHAR(100),
    -- CHECK: Validar que el género sea uno de los permitidos
    CONSTRAINT chk_patient_gender CHECK (gender IN ('M', 'F', 'O'))
);

-- 4. Tabla Rooms (Sin dependencias foráneas)
CREATE TABLE rooms (
    room_id SERIAL PRIMARY KEY,
    room_number VARCHAR(10) NOT NULL UNIQUE,
    room_type VARCHAR(20) NOT NULL,
    daily_rate DECIMAL(10, 2) NOT NULL,
    -- CHECK: Validar tipos de habitación y precio positivo
    CONSTRAINT chk_room_type CHECK (room_type IN ('General', 'UCI', 'Privada')),
    CONSTRAINT chk_room_price CHECK (daily_rate >= 0)
);

-- 5. Tabla Appointments (Depende de Patients y Doctors)
CREATE TABLE appointments (
    appointment_id SERIAL PRIMARY KEY,
    date_time TIMESTAMP NOT NULL,
    status VARCHAR(20) DEFAULT 'Programada',
    patient_id INT NOT NULL,
    doctor_id INT NOT NULL,
    -- FKs
    CONSTRAINT fk_app_patient FOREIGN KEY (patient_id) 
        REFERENCES patients(patient_id),
    CONSTRAINT fk_app_doctor FOREIGN KEY (doctor_id) 
        REFERENCES doctors(doctor_id),
    -- CHECK: Estados válidos
    CONSTRAINT chk_app_status CHECK (status IN ('Programada', 'Completada', 'Cancelada'))
);

-- 6. Tabla Admissions (Depende de Patients, Rooms y Doctors)
CREATE TABLE admissions (
    admission_id SERIAL PRIMARY KEY,
    admission_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    discharge_date TIMESTAMP,
    diagnosis TEXT NOT NULL,
    patient_id INT NOT NULL,
    room_id INT NOT NULL,
    doctor_id INT NOT NULL,
    -- FKs
    CONSTRAINT fk_adm_patient FOREIGN KEY (patient_id) 
        REFERENCES patients(patient_id),
    CONSTRAINT fk_adm_room FOREIGN KEY (room_id) 
        REFERENCES rooms(room_id),
    CONSTRAINT fk_adm_doctor FOREIGN KEY (doctor_id) 
        REFERENCES doctors(doctor_id),
    -- CHECK: La fecha de alta no puede ser anterior a la de admisión
    CONSTRAINT chk_dates CHECK (discharge_date >= admission_date)
);
