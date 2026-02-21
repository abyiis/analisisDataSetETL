-- ============================================================
-- TADB 202610 - Examen 01
-- Modelo de Datos: Buses Escolares Electricos
-- Motor: PostgreSQL (Supabase)
-- Autor: [juan david parra sierra] - ID SIGAA: [000475676]
-- Fecha: Febrero 2026
-- ============================================================

-- ------------------------------------------------------------
-- PASO 1: Verificacion del entorno
-- ------------------------------------------------------------
SELECT version();
SELECT current_schema();

-- ------------------------------------------------------------
-- PASO 2: Limpieza previa (ejecutar si se necesita reiniciar)
-- ------------------------------------------------------------
DROP TABLE IF EXISTS estadisticas_bus       CASCADE;
DROP TABLE IF EXISTS estadisticas_conductor CASCADE;
DROP TABLE IF EXISTS viajes                 CASCADE;
DROP TABLE IF EXISTS rutas                  CASCADE;
DROP TABLE IF EXISTS buses                  CASCADE;
DROP TABLE IF EXISTS conductores            CASCADE;
DROP TABLE IF EXISTS zonas                  CASCADE;
DROP TABLE IF EXISTS raw_viajes             CASCADE;

-- ------------------------------------------------------------
-- PASO 3: Tablas maestras
-- ------------------------------------------------------------

CREATE TABLE zonas (
    id_zona     SERIAL       PRIMARY KEY,
    nombre_zona VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE conductores (
    id_conductor     SERIAL       PRIMARY KEY,
    nombre_conductor VARCHAR(200) NOT NULL UNIQUE
);

CREATE TABLE buses (
    id_bus           SERIAL      PRIMARY KEY,
    codigo_bus       VARCHAR(50) NOT NULL UNIQUE,
    anio_fabricacion SMALLINT    NOT NULL
        CHECK (anio_fabricacion BETWEEN 2000 AND 2030)
);

CREATE TABLE rutas (
    id_ruta      SERIAL        PRIMARY KEY,
    codigo_ruta  VARCHAR(50)   NOT NULL UNIQUE,
    nombre_ruta  VARCHAR(200)  NOT NULL,
    id_zona      INTEGER       NOT NULL REFERENCES zonas(id_zona),
    distancia_km NUMERIC(6,2)  NOT NULL CHECK (distancia_km > 0)
);

-- ------------------------------------------------------------
-- PASO 4: Tabla de hechos
-- ------------------------------------------------------------

CREATE TABLE viajes (
    id_viaje           SERIAL        PRIMARY KEY,
    id_conductor       INTEGER       NOT NULL REFERENCES conductores(id_conductor),
    id_bus             INTEGER       NOT NULL REFERENCES buses(id_bus),
    id_ruta            INTEGER       NOT NULL REFERENCES rutas(id_ruta),
    turno              CHAR(2)       NOT NULL CHECK (turno IN ('AM','PM')),
    num_pasajeros      SMALLINT      NOT NULL CHECK (num_pasajeros >= 0),
    fecha_viaje        DATE          NOT NULL,
    hora_salida        TIME          NOT NULL,
    hora_llegada       TIME          NOT NULL,
    tiempo_minutos     NUMERIC(6,2)  NOT NULL CHECK (tiempo_minutos > 0),
    velocidad_promedio NUMERIC(6,2)  NOT NULL CHECK (velocidad_promedio > 0),
    soc_inicial        NUMERIC(5,2)  NOT NULL CHECK (soc_inicial  BETWEEN 0 AND 100),
    soc_final          NUMERIC(5,2)  NOT NULL CHECK (soc_final    BETWEEN 0 AND 100),
    soc_consumido      NUMERIC(5,2)  GENERATED ALWAYS AS (soc_inicial - soc_final) STORED
);

-- Indices para mejorar rendimiento
CREATE INDEX idx_viajes_conductor ON viajes(id_conductor);
CREATE INDEX idx_viajes_bus       ON viajes(id_bus);
CREATE INDEX idx_viajes_ruta      ON viajes(id_ruta);
CREATE INDEX idx_viajes_fecha     ON viajes(fecha_viaje);

-- ------------------------------------------------------------
-- PASO 5: Tablas de totalizacion (usadas en Etapa 5)
-- ------------------------------------------------------------

CREATE TABLE estadisticas_conductor (
    id_estadistica_conductor SERIAL      PRIMARY KEY,
    id_conductor             INTEGER     NOT NULL REFERENCES conductores(id_conductor),
    mes                      CHAR(7)     NOT NULL,
    cantidad_viajes          INTEGER     NOT NULL DEFAULT 0,
    velocidad_promedio       NUMERIC(6,2),
    UNIQUE(id_conductor, mes)
);

CREATE TABLE estadisticas_bus (
    id_estadistica_bus SERIAL      PRIMARY KEY,
    id_bus             INTEGER     NOT NULL REFERENCES buses(id_bus),
    mes                CHAR(7)     NOT NULL,
    cantidad_viajes    INTEGER     NOT NULL DEFAULT 0,
    soc_promedio       NUMERIC(6,2),
    UNIQUE(id_bus, mes)
);

-- ------------------------------------------------------------
-- PASO 6: Tabla temporal para carga del CSV
-- ------------------------------------------------------------

CREATE TABLE raw_viajes (
    nombre_conductor   TEXT,
    codigo_bus         TEXT,
    anio_fabricacion   TEXT,
    codigo_ruta        TEXT,
    nombre_ruta        TEXT,
    zona               TEXT,
    distancia_km       TEXT,
    turno              TEXT,
    num_pasajeros      TEXT,
    fecha_viaje        TEXT,
    hora_salida        TEXT,
    hora_llegada       TEXT,
    tiempo_minutos     TEXT,
    velocidad_promedio TEXT,
    soc_inicial        TEXT,
    soc_final          TEXT
);

-- ------------------------------------------------------------
-- PASO 7: Cargar CSV en raw_viajes
-- (Ejecutar desde psql o usar Import en DataGrip)
-- ------------------------------------------------------------

-- Opcion A: desde psql con archivo local
-- \COPY raw_viajes FROM '/ruta/al/archivo.csv'
--     WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8');

-- Opcion B: desde DataGrip
-- Clic derecho en raw_viajes > Import Data from File
-- Seleccionar el CSV, delimitador coma, primera fila encabezado

-- ------------------------------------------------------------
-- PASO 8: Normalizar y poblar tablas desde raw_viajes
-- ------------------------------------------------------------

-- Zonas
INSERT INTO zonas (nombre_zona)
SELECT DISTINCT TRIM(zona)
FROM raw_viajes
WHERE zona IS NOT NULL
ON CONFLICT (nombre_zona) DO NOTHING;

-- Conductores
INSERT INTO conductores (nombre_conductor)
SELECT DISTINCT TRIM(nombre_conductor)
FROM raw_viajes
WHERE nombre_conductor IS NOT NULL
ON CONFLICT (nombre_conductor) DO NOTHING;

-- Buses
INSERT INTO buses (codigo_bus, anio_fabricacion)
SELECT DISTINCT
    TRIM(codigo_bus),
    CAST(TRIM(anio_fabricacion) AS SMALLINT)
FROM raw_viajes
WHERE codigo_bus IS NOT NULL
ON CONFLICT (codigo_bus) DO NOTHING;

-- Rutas
INSERT INTO rutas (codigo_ruta, nombre_ruta, id_zona, distancia_km)
SELECT DISTINCT
    TRIM(r.codigo_ruta),
    TRIM(r.nombre_ruta),
    z.id_zona,
    CAST(REPLACE(TRIM(r.distancia_km), ',', '.') AS NUMERIC(6,2))
FROM raw_viajes r
JOIN zonas z ON z.nombre_zona = TRIM(r.zona)
WHERE r.codigo_ruta IS NOT NULL
ON CONFLICT (codigo_ruta) DO NOTHING;

-- Viajes
INSERT INTO viajes (
    id_conductor,
    id_bus,
    id_ruta,
    turno,
    num_pasajeros,
    fecha_viaje,
    hora_salida,
    hora_llegada,
    tiempo_minutos,
    velocidad_promedio,
    soc_inicial,
    soc_final
)
SELECT
    c.id_conductor,
    b.id_bus,
    rt.id_ruta,
    TRIM(r.turno),
    CAST(TRIM(r.num_pasajeros)      AS SMALLINT),
    TO_DATE(TRIM(r.fecha_viaje),    'YYYY-MM-DD'),
    CAST(TRIM(r.hora_salida)        AS TIME),
    CAST(TRIM(r.hora_llegada)       AS TIME),
    CAST(REPLACE(TRIM(r.tiempo_minutos),     ',', '.') AS NUMERIC(6,2)),
    CAST(REPLACE(TRIM(r.velocidad_promedio), ',', '.') AS NUMERIC(6,2)),
    CAST(REPLACE(TRIM(r.soc_inicial),        ',', '.') AS NUMERIC(5,2)),
    CAST(REPLACE(TRIM(r.soc_final),          ',', '.') AS NUMERIC(5,2))
FROM raw_viajes r
JOIN conductores c ON c.nombre_conductor = TRIM(r.nombre_conductor)
JOIN buses       b ON b.codigo_bus       = TRIM(r.codigo_bus)
JOIN rutas      rt ON rt.codigo_ruta     = TRIM(r.codigo_ruta);

-- ------------------------------------------------------------
-- PASO 9: Verificacion de la carga
-- ------------------------------------------------------------

SELECT 'zonas'        AS tabla, COUNT(*) AS total FROM zonas
UNION ALL
SELECT 'conductores',           COUNT(*)           FROM conductores
UNION ALL
SELECT 'buses',                 COUNT(*)           FROM buses
UNION ALL
SELECT 'rutas',                 COUNT(*)           FROM rutas
UNION ALL
SELECT 'viajes',                COUNT(*)           FROM viajes;
-- viajes debe mostrar 2280

-- ------------------------------------------------------------
-- PASO 10: Vistas de apoyo
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW v_detalle_viajes AS
SELECT
    v.id_viaje,
    c.nombre_conductor,
    b.codigo_bus,
    b.anio_fabricacion,
    rt.codigo_ruta,
    rt.nombre_ruta,
    z.nombre_zona,
    rt.distancia_km,
    v.turno,
    v.num_pasajeros,
    v.fecha_viaje,
    v.hora_salida,
    v.hora_llegada,
    v.tiempo_minutos,
    v.velocidad_promedio,
    v.soc_inicial,
    v.soc_final,
    v.soc_consumido
FROM viajes v
JOIN conductores c ON c.id_conductor = v.id_conductor
JOIN buses       b ON b.id_bus       = v.id_bus
JOIN rutas      rt ON rt.id_ruta     = v.id_ruta
JOIN zonas       z ON z.id_zona      = rt.id_zona;

CREATE OR REPLACE VIEW v_consumo_por_dia_semana AS
SELECT
    TO_CHAR(fecha_viaje, 'Day')    AS dia_semana,
    EXTRACT(DOW FROM fecha_viaje)  AS num_dia,
    COUNT(*)                       AS total_viajes,
    ROUND(AVG(soc_consumido), 2)   AS soc_consumido_promedio
FROM viajes
GROUP BY dia_semana, num_dia
ORDER BY num_dia;

CREATE OR REPLACE VIEW v_consumo_por_turno AS
SELECT
    turno,
    COUNT(*)                       AS total_viajes,
    ROUND(AVG(num_pasajeros), 1)   AS pasajeros_promedio,
    ROUND(AVG(soc_consumido), 2)   AS soc_consumido_promedio
FROM viajes
GROUP BY turno
ORDER BY turno;

-- ------------------------------------------------------------
-- PASO 11: Procedimientos (Etapa 5)
-- ------------------------------------------------------------

CREATE OR REPLACE PROCEDURE p_calcula_estadisticas_conductor()
LANGUAGE plpgsql AS $$
BEGIN
    TRUNCATE TABLE estadisticas_conductor RESTART IDENTITY;

    INSERT INTO estadisticas_conductor
        (id_conductor, mes, cantidad_viajes, velocidad_promedio)
    SELECT
        v.id_conductor,
        TO_CHAR(v.fecha_viaje, 'YYYY-MM') AS mes,
        COUNT(*)                          AS cantidad_viajes,
        ROUND(AVG(v.velocidad_promedio), 2)
    FROM viajes v
    GROUP BY v.id_conductor, TO_CHAR(v.fecha_viaje, 'YYYY-MM');

    RAISE NOTICE 'estadisticas_conductor: % filas insertadas.',
        (SELECT COUNT(*) FROM estadisticas_conductor);
END;
$$;

CREATE OR REPLACE PROCEDURE p_calcula_estadisticas_bus()
LANGUAGE plpgsql AS $$
BEGIN
    TRUNCATE TABLE estadisticas_bus RESTART IDENTITY;

    INSERT INTO estadisticas_bus
        (id_bus, mes, cantidad_viajes, soc_promedio)
    SELECT
        v.id_bus,
        TO_CHAR(v.fecha_viaje, 'YYYY-MM') AS mes,
        COUNT(*)                          AS cantidad_viajes,
        ROUND(AVG(v.soc_consumido), 2)
    FROM viajes v
    GROUP BY v.id_bus, TO_CHAR(v.fecha_viaje, 'YYYY-MM');

    RAISE NOTICE 'estadisticas_bus: % filas insertadas.',
        (SELECT COUNT(*) FROM estadisticas_bus);
END;
$$;

-- Ejecutar procedimientos
CALL p_calcula_estadisticas_conductor();
CALL p_calcula_estadisticas_bus();

-- ------------------------------------------------------------
-- PASO 1.5: Creacion de usuario con privilegios minimos
-- (Ejecutar conectado como postgres / usuario administrador)
-- ------------------------------------------------------------

-- Crear usuario de aplicacion
CREATE USER usr_buses_app WITH PASSWORD 'BusesApp2026*';

-- Conectar a la base de datos correcta
-- (en Supabase esto ya es 'postgres' por defecto)

-- Privilegios sobre el esquema
GRANT USAGE ON SCHEMA public TO usr_buses_app;

-- Privilegios de solo lectura y escritura en tablas de negocio
GRANT SELECT, INSERT, UPDATE, DELETE
    ON TABLE zonas, conductores, buses, rutas, viajes
    TO usr_buses_app;

-- Privilegios de solo lectura en tablas de totalizacion
GRANT SELECT
    ON TABLE estadisticas_conductor, estadisticas_bus
    TO usr_buses_app;

-- Privilegios para ejecutar los procedimientos
GRANT EXECUTE
    ON PROCEDURE p_calcula_estadisticas_conductor()
    TO usr_buses_app;

GRANT EXECUTE
    ON PROCEDURE p_calcula_estadisticas_bus()
    TO usr_buses_app;

-- Privilegios sobre las secuencias (necesario para SERIAL/INSERT)
GRANT USAGE, SELECT
    ON ALL SEQUENCES IN SCHEMA public
    TO usr_buses_app;

-- Privilegios sobre las vistas
GRANT SELECT
    ON TABLE v_detalle_viajes,
             v_consumo_por_dia_semana,
             v_consumo_por_turno
    TO usr_buses_app;

-- Verificar los privilegios asignados
SELECT grantee, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee = 'usr_buses_app'
ORDER BY table_name, privilege_type;