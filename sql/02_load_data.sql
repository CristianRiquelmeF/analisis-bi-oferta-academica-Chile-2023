-- =======================================================
-- SCRIPT 2: PROCESO ETL DE CARGA (DML)
-- Descripción: Limpia tablas y recarga datos desde CSV
-- =======================================================

USE educacion_chile_2023;

-- 1. CONFIGURACIÓN INICIAL
SET GLOBAL local_infile = 1; -- Habilita carga de archivos

-- 2. LIMPIEZA TOTAL (RESET)
-- Desactivamos revisión de llaves foráneas para poder borrar
SET FOREIGN_KEY_CHECKS = 0;

TRUNCATE TABLE fact_admision;
TRUNCATE TABLE fact_oferta;
TRUNCATE TABLE dim_carrera;
TRUNCATE TABLE dim_geografia;
TRUNCATE TABLE dim_institucion;

SET FOREIGN_KEY_CHECKS = 1;


-- 3. CARGA DE DIMENSIONES
-- -------------------------------------------------------

-- 3.1 Dimensión Institución
LOAD DATA LOCAL INFILE 'C:/Users/HP/Desktop/power_bi/PROYECTOS/oferta_academica2023/tablas/dim_institucion.csv'
INTO TABLE dim_institucion
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ';' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- 3.2 Dimensión Geografía
LOAD DATA LOCAL INFILE 'C:/Users/HP/Desktop/power_bi/PROYECTOS/oferta_academica2023/tablas/dim_geografia.csv'
INTO TABLE dim_geografia
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ';'
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- 3.3 Dimensión Carrera (Con mapeo de columnas especial)
LOAD DATA LOCAL INFILE 'C:/Users/HP/Desktop/power_bi/PROYECTOS/oferta_academica2023/tablas/dim_carrera.csv'
INTO TABLE dim_carrera
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ';'
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(carrera_generica, area_conocimiento, tipo_carrera, mencion, id_carrera_generica); -- Mapeo específico para reordenamiento


-- 4. CARGA DE TABLAS DE HECHOS
-- -------------------------------------------------------

-- 4.1 Fact Oferta
LOAD DATA LOCAL INFILE 'C:/Users/HP/Desktop/power_bi/PROYECTOS/oferta_academica2023/tablas/fact_oferta_2023.csv'
INTO TABLE fact_oferta
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ';'
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- 4.2 Fact Admisión
LOAD DATA LOCAL INFILE 'C:/Users/HP/Desktop/power_bi/PROYECTOS/oferta_academica2023/tablas/fact_admision_2023.csv'
INTO TABLE fact_admision
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ';'
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;


-- 5. REPORTE FINAL DE CARGA (AUDITORÍA)
-- -------------------------------------------------------
SELECT 'dim_institucion' as Tabla, COUNT(*) as Registros FROM dim_institucion
UNION ALL
SELECT 'dim_geografia', COUNT(*) FROM dim_geografia
UNION ALL
SELECT 'dim_carrera', COUNT(*) FROM dim_carrera
UNION ALL
SELECT 'fact_oferta', COUNT(*) FROM fact_oferta
UNION ALL
SELECT 'fact_admision', COUNT(*) FROM fact_admision; -- Consolidación final para validar ingesta exitosa