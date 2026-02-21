-- ============================================================
-- TADB 202610 - Examen 01
-- Consultas de Exploracion del Modelo
-- Motor: PostgreSQL (Supabase)
-- Autor: [juan david parra sierra] - ID SIGAA: [000475676]
-- Fecha: Febrero 2026
-- ============================================================

-- ------------------------------------------------------------
-- CONSULTA 1: Validacion distancia - consumo de bateria
-- ------------------------------------------------------------
-- Clasificacion:
--   Corto : 10 - 15 km
--   Medio : 16 - 27 km
--   Largo : 28 - 35 km
-- ------------------------------------------------------------

SELECT
    tipo_recorrido,
    COUNT(*)                          AS total_viajes,
    ROUND(AVG(distancia_km), 2)       AS distancia_promedio_km,
    ROUND(AVG(soc_consumido), 2)      AS soc_consumido_promedio
FROM (
    SELECT
        v.soc_consumido,
        rt.distancia_km,
        CASE
            WHEN rt.distancia_km BETWEEN 10 AND 15 THEN 'Corto'
            WHEN rt.distancia_km BETWEEN 16 AND 27 THEN 'Medio'
            WHEN rt.distancia_km BETWEEN 28 AND 35 THEN 'Largo'
        END AS tipo_recorrido
    FROM viajes v
    JOIN rutas rt ON rt.id_ruta = v.id_ruta
    WHERE rt.distancia_km BETWEEN 10 AND 35
) sub
GROUP BY tipo_recorrido
ORDER BY
    CASE tipo_recorrido
        WHEN 'Corto' THEN 1
        WHEN 'Medio' THEN 2
        WHEN 'Largo' THEN 3
    END;

/*
RESPUESTA 1:
Si el soc_consumido_promedio aumenta de Corto -> Medio -> Largo,
se confirma que a mayor distancia recorrida mayor es el consumo
de la bateria. Esto valida la hipotesis del modelo fisico propuesto.
*/

-- ------------------------------------------------------------
-- CONSULTA 2: Validacion cantidad de pasajeros - consumo de bateria
-- ------------------------------------------------------------
-- Clasificacion:
--   Pocos    :  5 - 12 pasajeros
--   Moderado : 13 - 22 pasajeros
--   Muchos   : 23 - 30 pasajeros
-- ------------------------------------------------------------

SELECT
    categoria_pasajeros,
    COUNT(*)                          AS total_viajes,
    ROUND(AVG(rt.distancia_km), 2)    AS distancia_promedio_km,
    ROUND(AVG(v.soc_consumido), 2)    AS soc_consumido_promedio
FROM viajes v
JOIN rutas rt ON rt.id_ruta = v.id_ruta
CROSS JOIN LATERAL (
    SELECT
        CASE
            WHEN v.num_pasajeros BETWEEN  5 AND 12 THEN 'Pocos'
            WHEN v.num_pasajeros BETWEEN 13 AND 22 THEN 'Moderado'
            WHEN v.num_pasajeros BETWEEN 23 AND 30 THEN 'Muchos'
            ELSE NULL
        END AS categoria_pasajeros
) cat
WHERE cat.categoria_pasajeros IS NOT NULL
GROUP BY cat.categoria_pasajeros
ORDER BY
    CASE cat.categoria_pasajeros
        WHEN 'Pocos'    THEN 1
        WHEN 'Moderado' THEN 2
        WHEN 'Muchos'   THEN 3
    END;

/*
RESPUESTA 2:
Si el soc_consumido_promedio incrementa de Pocos -> Moderado -> Muchos,
se confirma que a mayor cantidad de pasajeros mayor es el consumo
energetico del bus, dado que el motor electrico debe vencer
una mayor masa total en cada viaje.
*/

-- ------------------------------------------------------------
-- CONSULTA 3: Validacion velocidad - consumo de bateria
-- ------------------------------------------------------------
-- Clasificacion:
--   Lenta      :  0 - <30 km/h
--   Moderada   : 30 - <40 km/h
--   Optima     : 40 - <50 km/h
--   Rapida     : 50 - <60 km/h
--   Muy Rapida : 60+  km/h
-- ------------------------------------------------------------

SELECT
    tipo_velocidad,
    COUNT(*)                              AS total_viajes,
    ROUND(MIN(v.velocidad_promedio), 2)   AS vel_minima,
    ROUND(AVG(v.velocidad_promedio), 2)   AS vel_promedio,
    ROUND(MAX(v.velocidad_promedio), 2)   AS vel_maxima,
    ROUND(AVG(v.soc_consumido), 2)        AS soc_consumido_promedio
FROM viajes v
CROSS JOIN LATERAL (
    SELECT
        CASE
            WHEN v.velocidad_promedio >= 0  AND v.velocidad_promedio < 30 THEN 'Lenta'
            WHEN v.velocidad_promedio >= 30 AND v.velocidad_promedio < 40 THEN 'Moderada'
            WHEN v.velocidad_promedio >= 40 AND v.velocidad_promedio < 50 THEN 'Optima'
            WHEN v.velocidad_promedio >= 50 AND v.velocidad_promedio < 60 THEN 'Rapida'
            WHEN v.velocidad_promedio >= 60                               THEN 'Muy Rapida'
            ELSE NULL
        END AS tipo_velocidad
) vel
WHERE vel.tipo_velocidad IS NOT NULL
GROUP BY vel.tipo_velocidad
ORDER BY vel_promedio;

/*
RESPUESTA 3:
Si la categoria 'Optima' (40-50 km/h) muestra el menor
soc_consumido_promedio, se confirma que las velocidades optimas
tienen el menor consumo de bateria. Los motores electricos
operan con mayor eficiencia en rangos de velocidad intermedios,
mientras que velocidades bajas (arranques frecuentes) y altas
(mayor resistencia aerodinamica) incrementan el consumo.
*/