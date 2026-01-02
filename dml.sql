--JOINs múltiples (3+ tablas)-
SELECT 
    p.first_name AS nombre_paciente,
    p.last_name AS apellido_paciente,
    a.date_time AS fecha_cita,
    a.status AS estado,
    d.first_name AS nombre_doctor,
    d.last_name AS apellido_doctor
FROM appointments a
JOIN patients p ON a.patient_id = p.patient_id
JOIN doctors d ON a.doctor_id = d.doctor_id
LIMIT 20;
------------------------------------------------------
--Subconsultas correlacionadas-
SELECT 
    r1.room_number,
    r1.room_type,
    r1.daily_rate
FROM rooms r1
WHERE r1.daily_rate > (
    SELECT AVG(r2.daily_rate)
    FROM rooms r2
    WHERE r2.room_type = r1.room_type -- <--- Aquí ocurre la correlación
)
ORDER BY r1.room_type, r1.daily_rate DESC;
-------------------------------------------------------
--Funciones de agregación con GROUP BY y HAVING
SELECT 
    d.first_name,
    d.last_name,
    d.license_number,
    COUNT(a.appointment_id) AS total_citas_completadas
FROM doctors d
JOIN appointments a ON d.doctor_id = a.doctor_id
WHERE a.status = 'Completada'  -- 1. Filtramos primero solo las completadas
GROUP BY d.doctor_id, d.first_name, d.last_name, d.license_number -- 2. Agrupamos por doctor
HAVING COUNT(a.appointment_id) > 1700 -- 3. Filtramos los grupos (doctores) con más de 1700
ORDER BY total_citas_completadas DESC;
---------------------------------------------------
--Window functions (RANK, ROW_NUMBER, PARTITION BY)
SELECT 
    p.first_name,
    p.last_name,
    a.date_time AS fecha_cita,
    a.status,
    -- Reinicia el contador para cada paciente (PARTITION BY)
    -- Ordena por fecha descendente para que la más reciente sea la #1
    ROW_NUMBER() OVER (
        PARTITION BY a.patient_id 
        ORDER BY a.date_time DESC
    ) AS orden_cita
FROM appointments a
JOIN patients p ON a.patient_id = p.patient_id
-- Limitamos para visualizar el ejemplo rápido
LIMIT 20;
-------------------------------------------------
--Operaciones de conjuntos (UNION, INTERSECT, EXCEPT)
SELECT first_name, last_name, 'Doctor' AS tipo_persona
FROM doctors
UNION
SELECT first_name, last_name, 'Paciente' AS tipo_persona
ORDER BY last_name, first_name
LIMIT 20;
-----------------------------------------------
--Common Table Expressions (CTEs)
WITH CitasPorDepartamento AS (
    -- CTE 1: Calculamos el volumen de citas completadas por departamento
    SELECT 
        d.department_id,
        COUNT(a.appointment_id) AS total_citas
    FROM departments d
    JOIN doctors doc ON d.department_id = doc.department_id
    JOIN appointments a ON doc.doctor_id = a.doctor_id
    WHERE a.status = 'Completada'
    GROUP BY d.department_id
),
IngresosPorHabitacion AS (
    -- CTE 2: Calculamos los ingresos generados por las estancias (Días * Tarifa Diaria)
    -- Relacionamos: Admission -> Room (para precio) y Admission -> Doctor -> Department (para agrupar)
    SELECT 
        doc.department_id,
        SUM(
            -- En Postgres, restar timestamps da un intervalo. Extraemos los días.
            EXTRACT(DAY FROM (adm.discharge_date - adm.admission_date)) * r.daily_rate
        ) AS ingreso_estimado
    FROM admissions adm
    JOIN rooms r ON adm.room_id = r.room_id
    JOIN doctors doc ON adm.doctor_id = doc.doctor_id
    WHERE adm.discharge_date IS NOT NULL
    GROUP BY doc.department_id
)
-- Consulta Principal: Unimos las dos CTEs con la tabla base de departamentos
SELECT 
    dept.name AS departamento,
    dept.location AS ubicacion,
    COALESCE(cpd.total_citas, 0) AS citas_atendidas,
    TO_CHAR(COALESCE(iph.ingreso_estimado, 0), 'FM$999,999,999.00') AS facturacion_estancias
FROM departments dept
LEFT JOIN CitasPorDepartamento cpd ON dept.department_id = cpd.department_id
LEFT JOIN IngresosPorHabitacion iph ON dept.department_id = iph.department_id
ORDER BY iph.ingreso_estimado DESC NULLS LAST
LIMIT 15;
-------------------------------------------------------------------
--Consultas con CASE
SELECT 
    first_name,
    last_name,
    birth_date,
    -- Calculamos la edad exacta usando funciones de fecha de Postgres
    EXTRACT(YEAR FROM AGE(CURRENT_DATE, birth_date)) AS edad,
    -- Aplicamos lógica condicional para etiquetar al paciente
    CASE
        WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, birth_date)) < 18 THEN 'Pediátrico'
        WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, birth_date)) BETWEEN 18 AND 65 THEN 'Adulto'
        ELSE 'Tercera Edad (Riesgo)'
    END AS grupo_etario
FROM patients
LIMIT 20;
------------------------------------------------------------------
--Análisis temporal con fechas
SELECT 
    -- Extraemos el número de mes (1-12) para ordenar
    EXTRACT(MONTH FROM date_time) AS numero_mes,
    -- Obtenemos el nombre del mes en texto
    TO_CHAR(date_time, 'TMMonth') AS mes,
    COUNT(appointment_id) AS total_citas,
    -- Porcentaje del total anual (Análisis relativo)
    ROUND(
        COUNT(appointment_id) * 100.0 / SUM(COUNT(appointment_id)) OVER (), 
        2
    ) AS porcentaje_anual
FROM appointments
WHERE date_time BETWEEN '2023-01-01' AND '2023-12-31'
GROUP BY 1, 2
ORDER BY 1;
-------------------------------------------------------------
--Expresiones regulares o búsqueda de texto
SELECT 
    email,
    -- Extrae todo lo que está después de la arroba
    SUBSTRING(email FROM '@(.*)$') AS dominio
FROM patients
LIMIT 10;
-----------------------------------------------------------
---INSERT con subconsultas
CREATE TABLE audit_cancelled_appointments (
    audit_id SERIAL PRIMARY KEY,
    original_appt_id INT,
    cancel_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    patient_full_name VARCHAR(100),
    doctor_full_name VARCHAR(100),
    scheduled_date TIMESTAMP
);
INSERT INTO audit_cancelled_appointments (
    original_appt_id, 
    patient_full_name, 
    doctor_full_name, 
    scheduled_date
)
SELECT 
    a.appointment_id,
    p.first_name || ' ' || p.last_name, -- Concatenamos nombre paciente
    d.first_name || ' ' || d.last_name, -- Concatenamos nombre doctor
    a.date_time
FROM appointments a
JOIN patients p ON a.patient_id = p.patient_id
JOIN doctors d ON a.doctor_id = d.doctor_id
WHERE a.status = 'Cancelada' 
  AND a.date_time < '2023-06-01'; -- Ejemplo: Archivar solo el primer semestre
-----------------------------------------------------------------------------------
--INSERT múltiple
INSERT INTO rooms (room_number, room_type, daily_rate) 
VALUES 
    ('F-101', 'General', 120.00),
    ('F-102', 'General', 120.00),
    ('F-103', 'Privada', 250.50),
    ('F-104', 'UCI', 450.00),
    ('F-105', 'UCI', 450.00);
---------------------------------------------------------------------------------
--INSERT con valores calculados
CREATE TABLE budget_projections (
    projection_id SERIAL PRIMARY KEY,
    room_number VARCHAR(10),
    base_rate DECIMAL(10,2),
    tax_amount DECIMAL(10,2),
    total_estimated DECIMAL(10,2)
);
--------------------------------------------------------------------------------
--INSERT con manejo de duplicados (UPSERT)
INSERT INTO rooms (room_number, room_type, daily_rate)
VALUES 
    ('H-105', 'General', 180.00)
ON CONFLICT (room_number) 
DO UPDATE SET 
    daily_rate = EXCLUDED.daily_rate, -- Actualiza al nuevo valor que intentabas insertar
    room_type = EXCLUDED.room_type;   -- Actualiza el tipo por si cambió
----------------------------------------------------------------------------------
--UPDATE con JOIN
UPDATE appointments
SET status = 'Cancelada'
FROM doctors, departments
WHERE appointments.doctor_id = doctors.doctor_id
  AND doctors.department_id = departments.department_id
  AND departments.location = 'Edificio C'
  AND appointments.status = 'Programada';
----------------------------------------------------------------------------
--UPDATE con condicional con CASE
UPDATE rooms
SET daily_rate = CASE
    -- Las UCI aumentan un 15%
    WHEN room_type = 'UCI' THEN daily_rate * 1.15
    -- Las Privadas aumentan un 10%
    WHEN room_type = 'Privada' THEN daily_rate * 1.10
    -- Las Generales (y cualquier otra) aumentan solo un 5%
    ELSE daily_rate * 1.05
END;
------------------------------------------------------------------------
--UPDATE masivo
UPDATE patients
SET email = REPLACE(email, '@example.com', '@hospital-central.org')
WHERE email LIKE '%@example.com';
-----------------------------------------------------------------------
--UPDATE con subconsultas
UPDATE appointments
SET status = 'Cancelada'
WHERE status = 'Programada'
  AND patient_id IN (
      -- Subconsulta: Busca los IDs de pacientes que han estado en UCI
      SELECT adm.patient_id
      FROM admissions adm
      JOIN rooms r ON adm.room_id = r.room_id
      WHERE r.room_type = 'UCI'
      AND adm.admission_date > CURRENT_DATE - INTERVAL '1 month'
  );
----------------------------------------------------------------------
--DELETE con subconsultas
DELETE FROM patients
WHERE patient_id NOT IN (
    -- Subconsulta 1: Pacientes con al menos una cita
    SELECT DISTINCT patient_id FROM appointments
)
AND patient_id NOT IN (
    -- Subconsulta 2: Pacientes con al menos una admisión
    SELECT DISTINCT patient_id FROM admissions
);
-------------------------------------------------------------------
--DELETE con JOIN
DELETE FROM appointments
USING doctors, departments
WHERE appointments.doctor_id = doctors.doctor_id
  AND doctors.department_id = departments.department_id
  AND departments.location = 'Edificio D'
  AND appointments.status = 'Cancelada';
------------------------------------------------------------------
--Soft delete (marcado lógico)
UPDATE departments
SET is_active = FALSE
WHERE department_id = 10; -- O un nombre específico
SELECT * FROM departments 
WHERE is_active = TRUE; -- Solo mostramos los "vivos"
---------------------------------------------------------------------
--Archivado antes de eliminación
CREATE TABLE appointments_archive (
    -- Mismas columnas que la original
    appointment_id INT PRIMARY KEY,
    date_time TIMESTAMP,
    status VARCHAR(20),
    patient_id INT,
    doctor_id INT,
    -- Columna extra para auditoría: ¿Cuándo se archivó?
    archived_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
WITH deleted_rows AS (
    -- 1. Borramos de la tabla principal y retornamos los datos borrados
    DELETE FROM appointments
    WHERE date_time < '2023-04-01' 
      AND status IN ('Completada', 'Cancelada')
    RETURNING appointment_id, date_time, status, patient_id, doctor_id
)
-- 2. Insertamos esos datos 'al vuelo' en la tabla de archivo
INSERT INTO appointments_archive (appointment_id, date_time, status, patient_id, doctor_id)
SELECT * FROM deleted_rows;
-----------------------------------------------------------------------------------
--
