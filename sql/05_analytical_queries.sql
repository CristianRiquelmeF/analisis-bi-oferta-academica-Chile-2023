-- ==================================================================
-- SCRIPT 5: CONSULTAS AVANZADAS DE NEGOCIO (DQL)
-- Objetivo: Extracción de insights, auditoría de calidad y patrones analíticos
-- ==================================================================

USE educacion_chile_2023;

-- 1. ANÁLISIS FINANCIERO: Facturación Teórica Anual (Top 10)
-- Determina el volumen económico potencial por concepto de aranceles anuales brutas.
SELECT 
    i.nombre_institucion,
    i.tipo_institucion,
    FORMAT(SUM(f.valor_arancel * f.matricula_total), 0) AS facturacion_anual_estimada_clp,
    SUM(f.matricula_total) AS total_alumnos_matriculados
FROM fact_oferta f
INNER JOIN dim_institucion i ON f.id_institucion = i.id_institucion
GROUP BY i.nombre_institucion, i.tipo_institucion
ORDER BY SUM(f.valor_arancel * f.matricula_total) DESC
LIMIT 10;


-- 2. EFICIENCIA DE MERCADO: Tasa de Ocupación de Primer Año (Fill Rate)
-- Evalúa el nivel de atracción de la oferta académica frente a la matrícula real efectiva.
SELECT 
    c.carrera_generica,
    i.nombre_institucion,
    f.vacantes,
    (f.matricula_1er_anio_mujeres + f.matricula_1er_anio_hombres) AS matriculados_1er_anio,
    ROUND(((f.matricula_1er_anio_mujeres + f.matricula_1er_anio_hombres) / NULLIF(f.vacantes, 0)) * 100, 1) AS tasa_ocupacion_pct
FROM fact_oferta f
INNER JOIN dim_carrera c ON f.id_carrera_generica = c.id_carrera_generica
INNER JOIN dim_institucion i ON f.id_institucion = i.id_institucion
WHERE f.vacantes > 10 -- Remoción de sesgos por programas experimentales o minoritarios
ORDER BY tasa_ocupacion_pct DESC
LIMIT 15;


-- 3. RELACIÓN CALIDAD-PRECIO: Identificación de "Joyas Ocultas"
-- Filtrado de alta selectividad (Puntaje Corte > 600) con costos inferiores a la media del mercado.
SELECT 
    c.carrera_generica,
    i.nombre_institucion,
    fa.puntaje_corte,
    f.valor_arancel
FROM fact_admision fa
INNER JOIN fact_oferta f ON fa.id_oferta = f.id_oferta
INNER JOIN dim_carrera c ON f.id_carrera_generica = c.id_carrera_generica
INNER JOIN dim_institucion i ON f.id_institucion = i.id_institucion
WHERE fa.puntaje_corte > 600 
  AND f.valor_arancel < (SELECT AVG(valor_arancel) FROM fact_oferta WHERE valor_arancel > 0)
ORDER BY fa.puntaje_corte DESC, f.valor_arancel ASC
LIMIT 10;


-- 4. SEGMENTACIÓN TERRITORIAL: Máximos Regionales mediante Funciones de Ventana
-- Devuelve la carrera de mayor costo arancelario para cada una de las regiones sin realizar escaneos iterativos redundantes.
WITH RankingCostos AS (
    SELECT 
        g.nombre_region,
        i.nombre_institucion,
        c.carrera_generica,
        f.valor_arancel,
        ROW_NUMBER() OVER(PARTITION BY g.nombre_region ORDER BY f.valor_arancel DESC) AS ranking_interno
    FROM fact_oferta f
    INNER JOIN dim_geografia g ON f.id_sede = g.id_sede
    INNER JOIN dim_institucion i ON f.id_institucion = i.id_institucion
    INNER JOIN dim_carrera c ON f.id_carrera_generica = c.id_carrera_generica
)
SELECT 
    nombre_region,
    nombre_institucion,
    carrera_generica,
    valor_arancel
FROM RankingCostos 
WHERE ranking_interno = 1;


-- 5. ANÁLISIS DE SEGREGACIÓN: Carreras con Alta Masculinización
-- Identifica programas de alta densidad estudiantil donde la participación femenina es crítica (inferior al 10%).
SELECT 
    c.carrera_generica,
    SUM(f.matricula_total) AS total_alumnos,
    SUM(f.matricula_mujeres) AS total_mujeres,
    ROUND((SUM(f.matricula_mujeres) / SUM(f.matricula_total)) * 100, 1) AS pct_mujeres
FROM fact_oferta f
INNER JOIN dim_carrera c ON f.id_carrera_generica = c.id_carrera_generica
GROUP BY c.carrera_generica
HAVING pct_mujeres < 10.0 AND total_alumnos > 500
ORDER BY pct_mujeres ASC;


-- 6. ASIMETRÍA CENTRALISTA: Macro-análisis de Concentración Santiago vs Regiones
-- Mide las disparidades en costos y volumen de matrícula entre la Región Metropolitana y el resto del país.
SELECT 
    CASE 
        WHEN g.nombre_region LIKE '%Metropolitana%' THEN 'RM - Santiago'
        ELSE 'Regiones'
    END AS zona_geografica,
    COUNT(DISTINCT f.id_institucion) AS cantidad_instituciones_activas,
    ROUND(AVG(f.valor_arancel), 0) AS arancel_promedio_clp,
    SUM(f.matricula_total) AS masa_estudiantil_total
FROM fact_oferta f
INNER JOIN dim_geografia g ON f.id_sede = g.id_sede
GROUP BY zona_geografica;


-- 7. ANÁLISIS DE EFICIENCIA FORMATIVA: Carreras Técnicas Cortas de Mayor Costo
-- Filtrado de carreras ciclo corto (<= 5 semestres) evaluadas mediante la función de costo total.
SELECT 
    c.carrera_generica,
    i.nombre_institucion,
    f.duracion_semestres,
    fn_calcular_costo_total(f.valor_arancel, f.valor_matricula, f.valor_titulo, f.duracion_semestres) AS costo_total_programa
FROM fact_oferta f
INNER JOIN dim_carrera c ON f.id_carrera_generica = c.id_carrera_generica
INNER JOIN dim_institucion i ON f.id_institucion = i.id_institucion
WHERE f.duracion_semestres <= 5 AND i.tipo_institucion IN ('I.P.', 'C.F.T.')
ORDER BY costo_total_programa DESC
LIMIT 10;


-- 8. AUDITORÍA DE CALIDAD DE DATOS (Data Quality & Sanity Check)
-- Escaneo de anomalías lógicas estructurales. El éxito de este script implica un retorno de 0 filas.
SELECT 
    f.id_oferta,
    i.nombre_institucion,
    c.carrera_generica,
    f.valor_arancel,
    f.duracion_semestres,
    f.matricula_mujeres,
    f.matricula_total
FROM fact_oferta f
INNER JOIN dim_institucion i ON f.id_institucion = i.id_institucion
INNER JOIN dim_carrera c ON f.id_carrera_generica = c.id_carrera_generica
WHERE (f.valor_arancel = 0 AND f.valor_matricula > 100000) -- Anomalía 1: Arancel costo cero pero matrícula elevada
   OR (f.duracion_semestres > 16)                           -- Anomalía 2: Duraciones superiores a 8 años académicos
   OR (f.matricula_mujeres > f.matricula_total);             -- Anomalía 3: Inconsistencia matemática de subgrupos


-- 9. DIVERSIFICACIÓN ACADÉMICA: Índice Multidisciplinario por Institución
-- Identifica qué corporaciones cubren el mayor espectro de áreas del conocimiento.
SELECT 
    i.nombre_institucion,
    COUNT(DISTINCT c.area_conocimiento) AS areas_distintas_cubiertas,
    COUNT(f.id_oferta) AS total_programas_ofrecidos
FROM fact_oferta f
INNER JOIN dim_institucion i ON f.id_institucion = i.id_institucion
INNER JOIN dim_carrera c ON f.id_carrera_generica = c.id_carrera_generica
GROUP BY i.nombre_institucion
ORDER BY areas_distintas_cubiertas DESC, total_programas_ofrecidos DESC
LIMIT 10;


-- 10. REPORTE GENERAL CON CTE (Estructura de consumo agregada)
WITH ResumenPorArea AS (
    SELECT 
        c.area_conocimiento,
        COUNT(*) AS total_programas,
        AVG(f.valor_arancel) AS arancel_promedio,
        SUM(f.matricula_total) AS total_alumnos
    FROM fact_oferta f
    INNER JOIN dim_carrera c ON f.id_carrera_generica = c.id_carrera_generica
    GROUP BY c.area_conocimiento
)
SELECT 
    area_conocimiento,
    total_programas,
    CONCAT('$', FORMAT(arancel_promedio, 0)) AS arancel_promedio_fmt,
    FORMAT(total_alumnos, 0) AS poblacion_estudiantil
FROM ResumenPorArea
ORDER BY total_alumnos DESC;