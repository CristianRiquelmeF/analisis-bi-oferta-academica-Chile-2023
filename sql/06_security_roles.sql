-- ==================================================================
-- SCRIPT 6: GOBIERNO DE DATOS, ACCESOS (DCL) Y PRUEBAS (DML)
-- ==================================================================

USE educacion_chile_2023;

-- ==================================================================
-- SECCIÓN A: COMPONENTES DE SEGURIDAD (Data Control Language)
-- ==================================================================
-- Implementación del Principio de Mínimo Privilegio.

-- 1. Perfil: Analista Junior (Restricción estricta de consumo)
DROP USER IF EXISTS 'analista_junior'@'localhost';
CREATE USER 'analista_junior'@'localhost' IDENTIFIED BY 'Pass1234!';

-- Otorgamiento exclusivo de lectura sobre el esquema (incluyendo la nueva vista analítica)
GRANT SELECT ON educacion_chile_2023.* TO 'analista_junior'@'localhost';
REVOKE DELETE, UPDATE, INSERT ON educacion_chile_2023.* FROM 'analista_junior'@'localhost';


-- 2. Perfil: Gestor de Infraestructura de Datos (Operatividad sin borrado)
DROP USER IF EXISTS 'gestor_datos'@'localhost';
CREATE USER 'gestor_datos'@'localhost' IDENTIFIED BY 'PassSegura5678!';

-- Permisos operacionales requeridos para flujos ETL de corrección
GRANT SELECT, INSERT, UPDATE ON educacion_chile_2023.* TO 'gestor_datos'@'localhost';
REVOKE DELETE ON educacion_chile_2023.* FROM 'gestor_datos'@'localhost';

-- Consolidación y actualización de privilegios en el motor de la base de datos
FLUSH PRIVILEGES;


-- ==================================================================
-- SECCIÓN B: TRAZABILIDAD Y PRUEBAS OPERATIVAS (DML)
-- ==================================================================

-- 1. Verificación de Procedimiento de Inserción
CALL sp_insertar_institucion(9999, 'UNIVERSIDAD DE DATA SCIENCE', 'Univ.');

-- Validación del estado físico del registro insertado
SELECT * FROM dim_institucion WHERE id_institucion = 9999;


-- 2. Verificación de Procedimiento de Corrección Estructural
CALL sp_actualizar_nombre_sede(1, 'CAMPUS PRINCIPAL - RENOVADO');


-- 3. Validación de Cálculo Cruzado de Funciones en Consultas Complejas
-- Comparativa de inversión total proyectada para programas de alta selectividad.
SELECT 
    i.nombre_institucion, 
    c.carrera_generica,
    f.valor_arancel,
    f.duracion_semestres,
    fn_calcular_costo_total(f.valor_arancel, f.valor_matricula, f.valor_titulo, f.duracion_semestres) AS inversion_total_estimada
FROM fact_oferta f
INNER JOIN dim_institucion i ON f.id_institucion = i.id_institucion
INNER JOIN dim_carrera c ON f.id_carrera_generica = c.id_carrera_generica
WHERE c.carrera_generica LIKE '%Medicina%'
  AND i.id_institucion IN (1001, 1002) -- Códigos representativos
LIMIT 5;


-- 4. Prueba de Consumo sobre la Vista de Power BI (vw_fact_educacion_consolidada)
-- Verificación del comportamiento del LEFT JOIN con los nuevos tipos DECIMAL.
SELECT 
    id_oferta,
    valor_arancel,
    costo_estimado_total,
    puntaje_corte,
    promedio_nem
FROM vw_fact_educacion_consolidada
WHERE puntaje_corte IS NOT NULL
ORDER BY puntaje_corte DESC
LIMIT 5;