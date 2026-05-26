-- ==================================================================
-- SCRIPT 1: CREACIÓN DE ESQUEMA (DDL)
-- Proyecto: Oferta Académica Educación Superior Chile 2023
-- ==================================================================

-- 1. Crear la Base de Datos
CREATE DATABASE IF NOT EXISTS educacion_chile_2023;
USE educacion_chile_2023;

-- ==================================================================
-- CONTROL DE RE-EJECUCIÓN: BORRADO PREVENTIVO DE TABLAS
-- ==================================================================
-- Desactivamos la revisión de llaves foráneas para evitar conflictos
-- al eliminar tablas vinculadas por relaciones jerárquicas.
SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS fact_admision;
DROP TABLE IF EXISTS fact_oferta;
DROP TABLE IF EXISTS dim_carrera;
DROP TABLE IF EXISTS dim_geografia;
DROP TABLE IF EXISTS dim_institucion;

-- Reactivamos la verificación de restricciones relacionales
SET FOREIGN_KEY_CHECKS = 1;


-- ==================================================================
-- 2. TABLAS DE DIMENSIONES (Contexto descriptivo)
-- ==================================================================

-- Tabla Dimensión: INSTITUCION
-- Contiene los atributos de quién imparte la carrera
CREATE TABLE dim_institucion (
    id_institucion INT PRIMARY KEY,
    nombre_institucion VARCHAR(150),
    tipo_institucion VARCHAR(100),
    clasificacion1 VARCHAR(100), -- CRUCH, Estatal, Privada, etc.
    clasificacion2 VARCHAR(100),
    clasificacion3 VARCHAR(100)  -- Nivel de Acreditación
);

-- Tabla Dimensión: GEOGRAFIA
-- Contiene la ubicación física y distribución territorial
CREATE TABLE dim_geografia (
    id_sede INT PRIMARY KEY,
    nombre_sede VARCHAR(150),
    nombre_campus VARCHAR(150),
    comuna VARCHAR(100),
    nombre_region VARCHAR(100),
    orden_region INT
);

-- Tabla Dimensión: CARRERA
-- Catálogo y clasificación de disciplinas académicas
CREATE TABLE dim_carrera (
    id_carrera_generica INT PRIMARY KEY,
    carrera_generica VARCHAR(150),
    area_conocimiento VARCHAR(150),
    tipo_carrera VARCHAR(100),
    mencion TEXT
);


-- ==================================================================
-- 3. TABLAS DE HECHOS (Métricas cuantitativas)
-- ==================================================================

-- Tabla de Hechos Principal: FACT_OFERTA
-- Contiene métricas financieras, vacantes e índices de matrícula
CREATE TABLE fact_oferta (
    id_oferta INT PRIMARY KEY, -- Código único de la carrera en el año
    id_institucion INT,
    id_sede INT,
    id_carrera_generica INT,
    duracion_semestres FLOAT,
    valor_matricula INT,
    valor_arancel INT,
    valor_titulo INT,
    vacantes INT,
    matricula_total INT,
    matricula_mujeres INT,
    matricula_hombres INT,
    matricula_extranjeros INT,
    matricula_1er_anio_mujeres INT,
    matricula_1er_anio_hombres INT,
    matricula_1er_anio_extranjeros INT,
    
    -- Definición de Restricciones Relacionales (Foreign Keys)
    CONSTRAINT fk_oferta_institucion FOREIGN KEY (id_institucion) REFERENCES dim_institucion(id_institucion),
    CONSTRAINT fk_oferta_geografia FOREIGN KEY (id_sede) REFERENCES dim_geografia(id_sede),
    CONSTRAINT fk_oferta_carrera FOREIGN KEY (id_carrera_generica) REFERENCES dim_carrera(id_carrera_generica)
);

-- Tabla de Hechos Secundaria: FACT_ADMISION
-- Contiene puntajes de selección. Relación 1:1 con Fact_Oferta
-- NOTA DE INGENIERÍA: Tipos de datos corregidos a DECIMAL para prevenir errores de redondeo en Power BI.
CREATE TABLE fact_admision (
    id_oferta INT PRIMARY KEY,
    promedio_lenguaje_mate DECIMAL(10,2),
    puntaje_corte DECIMAL(10,2),
    promedio_nem DECIMAL(10,2),
    promedio_ranking DECIMAL(10,2),
    alumnos_ingreso_psu INT,
    
    -- Conexión directa a la oferta específica
    CONSTRAINT fk_admision_oferta FOREIGN KEY (id_oferta) REFERENCES fact_oferta(id_oferta)
);