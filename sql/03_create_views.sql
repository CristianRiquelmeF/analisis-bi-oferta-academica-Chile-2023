-- ==================================================================
-- SCRIPT 3: VISTAS ANALÍTICAS (VIEWS)
-- Proyecto: Oferta Académica Educación Superior Chile 2023
-- ==================================================================
USE educacion_chile_2023;

-- ==================================================================
-- SECCIÓN A: VISTA OPTIMIZADA PARA BI (STAR SCHEMA)
-- ==================================================================

-- 1. VISTA MAESTRA PARA POWER BI: Oferta y Admisión Consolidada
-- Objetivo: Resolver cardinalidad 1:1 y delegar cálculos de fila a la base de datos.
-- IMPORTANTE: Esta es la ÚNICA tabla de hechos que debe importarse a Power BI.
CREATE OR REPLACE VIEW vw_fact_educacion_consolidada AS
SELECT 
    -- Llaves Foráneas
    o.id_oferta,
    o.id_institucion,
    o.id_sede,
    o.id_carrera_generica,
    
    -- Métricas de Duración y Costos
    o.duracion_semestres,
    o.valor_matricula,
    o.valor_arancel,
    o.valor_titulo,
    
    -- Cálculo de costo total delegado a MySQL (Máxima de Roche)
    ((o.valor_arancel + o.valor_matricula) * (o.duracion_semestres / 2)) + o.valor_titulo AS costo_estimado_total,
    
    -- Métricas de Capacidad
    o.vacantes,
    o.matricula_total,
    o.matricula_mujeres,
    o.matricula_hombres,
    o.matricula_extranjeros,
    o.matricula_1er_anio_mujeres,
    o.matricula_1er_anio_hombres,
    o.matricula_1er_anio_extranjeros,
    
    -- Métricas de Admisión (Ajustadas a nuevos tipos DECIMAL)
    a.promedio_lenguaje_mate,
    a.puntaje_corte,
    a.promedio_nem,
    a.promedio_ranking,
    a.alumnos_ingreso_psu
    
FROM fact_oferta o
LEFT JOIN fact_admision a ON o.id_oferta = a.id_oferta;


-- ==================================================================
-- SECCIÓN B: VISTAS DE REPORTE TRADICIONAL (PORTAFOLIO SQL)
-- ==================================================================
-- Estas vistas pre-agregan y aplanan los datos. Son excelentes para 
-- consultas rápidas o exportaciones a Excel, pero rompen el Esquema 
-- en Estrella, por lo que NO deben conectarse a Power BI.

-- 2. VISTA PLANA: OBT (One Big Table) de Oferta
-- Objetivo: Sábana de datos desnormalizada para lectura humana.
CREATE OR REPLACE VIEW vw_oferta_completa_plana AS
SELECT 
    f.id_oferta,
    i.nombre_institucion,
    i.tipo_institucion,
    i.clasificacion1 AS grupo_cruch,
    i.clasificacion3 AS acreditacion,
    c.carrera_generica,
    c.area_conocimiento,
    c.tipo_carrera,
    g.nombre_sede,
    g.nombre_region,
    g.comuna,
    f.duracion_semestres,
    f.valor_arancel,
    f.valor_matricula,
    fn_calcular_costo_total(f.valor_arancel, f.valor_matricula, f.valor_titulo, f.duracion_semestres) AS costo_estimado_total,
    f.vacantes,
    f.matricula_total,
    f.matricula_mujeres,
    f.matricula_hombres,
    ROUND((f.matricula_mujeres / NULLIF(f.matricula_total, 0)) * 100, 1) AS pct_mujeres
FROM fact_oferta f
INNER JOIN dim_institucion i ON f.id_institucion = i.id_institucion
INNER JOIN dim_geografia g ON f.id_sede = g.id_sede
INNER JOIN dim_carrera c ON f.id_carrera_generica = c.id_carrera_generica;


-- 3. VISTA DE CALIDAD: Top Carreras por Exigencia
-- Objetivo: Ranking de puntajes de corte con funciones de ventana.
CREATE OR REPLACE VIEW vw_ranking_exigencia_academica AS
SELECT 
    ROW_NUMBER() OVER (ORDER BY fa.puntaje_corte DESC) AS ranking_nacional,
    c.carrera_generica,
    i.nombre_institucion,
    g.nombre_region,
    fa.puntaje_corte,
    fa.promedio_nem,
    fa.promedio_ranking,
    f.vacantes
FROM fact_admision fa
INNER JOIN fact_oferta f ON fa.id_oferta = f.id_oferta
INNER JOIN dim_carrera c ON f.id_carrera_generica = c.id_carrera_generica
INNER JOIN dim_institucion i ON f.id_institucion = i.id_institucion
INNER JOIN dim_geografia g ON f.id_sede = g.id_sede
WHERE fa.puntaje_corte > 0;


-- 4. VISTA RESUMEN: Costos Promedio por Región
-- Objetivo: Datos agregados para análisis macro territorial.
CREATE OR REPLACE VIEW vw_resumen_costos_region AS
SELECT 
    g.nombre_region,
    i.tipo_institucion,
    COUNT(f.id_oferta) AS cantidad_programas,
    ROUND(AVG(f.valor_arancel), 0) AS promedio_arancel,
    SUM(f.vacantes) AS oferta_vacantes_total
FROM fact_oferta f
INNER JOIN dim_geografia g ON f.id_sede = g.id_sede
INNER JOIN dim_institucion i ON f.id_institucion = i.id_institucion
GROUP BY g.nombre_region, i.tipo_institucion;


-- 5. VISTA DE GÉNERO: Análisis de Paridad y Brecha Estructural
-- Objetivo: Clasificación sociológica de áreas del conocimiento según segregación de género.
CREATE OR REPLACE VIEW vw_analisis_genero_areas AS
SELECT 
    c.area_conocimiento,
    SUM(f.matricula_total) AS total_matriculados,
    SUM(f.matricula_mujeres) AS total_mujeres,
    SUM(f.matricula_hombres) AS total_hombres,
    ROUND((SUM(f.matricula_mujeres) / NULLIF(SUM(f.matricula_total), 0)) * 100, 1) AS pct_participacion_mujer,
    CASE 
        WHEN (SUM(f.matricula_mujeres) / NULLIF(SUM(f.matricula_total), 0)) < 0.40 THEN 'Brecha Masculina (>60% Hombres)'
        WHEN (SUM(f.matricula_mujeres) / NULLIF(SUM(f.matricula_total), 0)) > 0.60 THEN 'Brecha Femenina (>60% Mujeres)'
        ELSE 'Paridad Relativa (40-60%)'
    END AS estado_paridad
FROM fact_oferta f
INNER JOIN dim_carrera c ON f.id_carrera_generica = c.id_carrera_generica
GROUP BY c.area_conocimiento;