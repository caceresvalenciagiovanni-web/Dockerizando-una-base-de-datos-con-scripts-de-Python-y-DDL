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
--BEGIN/COMMIT/ROLLBACK
-- 1. Iniciamos la transacción (A partir de aquí, nada es definitivo hasta el COMMIT)
BEGIN;

    -- Paso A: Intentamos cerrar la cita médica
    UPDATE appointments
    SET status = 'Completada'
    WHERE appointment_id = 50500; -- ID de ejemplo de una cita existente

    -- Paso B: Insertamos la admisión usando los datos de la misma cita
    -- Nota: Usamos subconsultas para asegurar que sea el mismo paciente y doctor
    INSERT INTO admissions (
        admission_date, 
        diagnosis, 
        patient_id, 
        room_id, 
        doctor_id
    )
    VALUES (
        CURRENT_TIMESTAMP, 
        'Ingreso de Urgencia - Derivado de Consulta',
        (SELECT patient_id FROM appointments WHERE appointment_id = 50500),
        (SELECT room_id FROM rooms WHERE room_type = 'UCI' LIMIT 1), -- Buscamos una UCI cualquiera
        (SELECT doctor_id FROM appointments WHERE appointment_id = 50500)
    );

-- 2. Si llegamos aquí sin errores, guardamos los cambios permanentemente
COMMIT;
--------------------------------------------------------------------------
--SAVEPOINTs
BEGIN;

    -- 1. Paso Crítico: Registramos al paciente (Esto NO queremos perderlo)
    INSERT INTO patients (dni, first_name, last_name, birth_date, gender, email)
    VALUES ('DNI-EMERG-99', 'Laura', 'Gomez', '1985-06-15', 'F', 'laura.urgencia@example.com');

    -- CREAMOS EL PUNTO DE GUARDADO
    -- Si algo falla después de aquí, volveremos a este estado (Paciente registrado, pero sin admisión)
    SAVEPOINT intento_vip;

    -- 2. Paso Arriesgado: Intentamos crear admisión en una habitación específica (ej. ID 99999 inexistente)
    -- Imaginemos que el código de la aplicación prueba primero con una Suite de lujo
    INSERT INTO admissions (admission_date, diagnosis, patient_id, room_id, doctor_id)
    VALUES (
        CURRENT_TIMESTAMP, 
        'Observación Preferencial',
        (SELECT patient_id FROM patients WHERE dni = 'DNI-EMERG-99'),
        99999, -- <--- ID DE HABITACIÓN INVÁLIDO (Causará error de Foreign Key)
        (SELECT doctor_id FROM doctors LIMIT 1)
    );

    -- ... En este punto, la base de datos lanza un ERROR ...
    -- Tu aplicación captura el error y decide: "Ok, no funcionó la VIP, volvamos atrás pero no borremos al paciente".

    -- 3. Recuperación: Deshacemos SOLO la inserción fallida de la admisión
    ROLLBACK TO SAVEPOINT intento_vip;
    
    -- Nota: En este momento, el paciente 'Laura Gomez' SIGUE insertado en la memoria de la transacción.

    -- 4. Plan B: Asignamos una habitación estándar que sabemos que existe (Busca una General)
    INSERT INTO admissions (admission_date, diagnosis, patient_id, room_id, doctor_id)
    VALUES (
        CURRENT_TIMESTAMP, 
        'Observación Estándar (Fallback)',
        (SELECT patient_id FROM patients WHERE dni = 'DNI-EMERG-99'),
        (SELECT room_id FROM rooms WHERE room_type = 'General' LIMIT 1), -- <--- ID VÁLIDO
        (SELECT doctor_id FROM doctors LIMIT 1)
    );

-- 5. Guardamos todo (El paciente Y la admisión estándar)
COMMIT;
---------------------------------------------------------------------------------
--Niveles de aislamiento
BEGIN;

-- 1. Establecemos el nivel de aislamiento ALTO para congelar la vista de los datos
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;

    -- Paso A: Consultamos el total global (Ej. $50,000)
    SELECT SUM(r.daily_rate) 
    FROM admissions a
    JOIN rooms r ON a.room_id = r.room_id
    WHERE a.admission_date >= '2023-01-01';

    -- [SIMULACIÓN DE TIEMPO]
    -- Imagina que justo AQUÍ, otra transacción inserta una nueva admisión de $500.
    -- En modo normal, el siguiente query vería esos $500 extra.
    -- En REPEATABLE READ, el siguiente query ignorará esa nueva inserción.

    -- Paso B: Consultamos el detalle para el reporte
    SELECT r.room_type, SUM(r.daily_rate)
    FROM admissions a
    JOIN rooms r ON a.room_id = r.room_id
    WHERE a.admission_date >= '2023-01-01'
    GROUP BY r.room_type;

-- 2. Terminamos. Los datos del Paso A y Paso B serán matemáticamente consistentes.
COMMIT;
----------------------------------------------------------------------------------------
--Manejo de bloqueos (FOR UPDATE)-
BEGIN;

    -- 1. BLOQUEO DE FILA (Row-Level Locking)
    -- Seleccionamos la habitación y la bloqueamos.
    -- Si otra transacción intenta hacer esto mismo para la 'H-205', 
    -- se quedará ESPERANDO (congelada) aquí hasta que nosotros hagamos COMMIT.
    SELECT room_id, daily_rate 
    FROM rooms 
    WHERE room_number = 'H-205' 
    FOR UPDATE;

    -- [Aquí tu aplicación verificaría en Python/Backend si la habitación 
    -- realmente está libre consultando la tabla admissions, pero la fila de 'rooms'
    -- ya es nuestra, nadie puede modificar su precio o borrarla].

    -- 2. OPERACIÓN CRÍTICA
    -- Insertamos la admisión sabiendo que nadie pudo modificar la habitación 
    -- en los microsegundos anteriores.
    INSERT INTO admissions (
        admission_date, 
        diagnosis, 
        patient_id, 
        room_id, 
        doctor_id
    )
    VALUES (
        CURRENT_TIMESTAMP, 
        'Ingreso Bloqueado Seguro', 
        (SELECT patient_id FROM patients WHERE dni = 'DNI-10020'), 
        (SELECT room_id FROM rooms WHERE room_number = 'H-205'), 
        (SELECT doctor_id FROM doctors LIMIT 1)
    );

-- 3. LIBERACIÓN
-- Al confirmar, se suelta el bloqueo y el siguiente en la fila (si lo hay) puede pasar.
COMMIT;
----------------------------------------------------------------------------
--Control de errores y rollback
DO $$
DECLARE
    nuevo_patient_id INT;
BEGIN
    -- 1. Intentamos registrar al paciente (Operación Exitosa)
    INSERT INTO patients (dni, first_name, last_name, birth_date, gender, email)
    VALUES ('DNI-TEST-FAIL', 'Juan', 'SinSuerte', '1980-01-01', 'M', 'juan.error@test.com')
    RETURNING patient_id INTO nuevo_patient_id;

    RAISE NOTICE 'Paciente creado temporalmente con ID: %', nuevo_patient_id;

    -- 2. Intentamos agendar una cita con un DOCTOR QUE NO EXISTE (ID -999)
    -- Esto violará la Foreign Key 'fk_app_doctor' definida en tu DDL
    INSERT INTO appointments (date_time, status, patient_id, doctor_id)
    VALUES (CURRENT_TIMESTAMP, 'Programada', nuevo_patient_id, -999);

    -- Si llegamos aquí, confirmamos todo (COMMIT implícito del bloque)
    RAISE NOTICE '¡Proceso completado con éxito!';

EXCEPTION
    -- 3. CONTROL DE ERRORES: Capturamos la violación de llave foránea
    WHEN foreign_key_violation THEN
        RAISE NOTICE 'ERROR CAPTURADO: El doctor asignado no existe.';
        RAISE NOTICE '>>> ROLLBACK AUTOMÁTICO: Se eliminó al paciente ID % para evitar datos huérfanos.', nuevo_patient_id;
        -- En PL/pgSQL, al entrar al bloque EXCEPTION, todo lo hecho en el bloque BEGIN se revierte.

    -- Capturamos cualquier otro error imprevisto
    WHEN OTHERS THEN
        RAISE NOTICE 'Ocurrió un error inesperado: %', SQLERRM;
END $$;
