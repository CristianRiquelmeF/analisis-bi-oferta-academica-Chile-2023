-- ==================================================================
-- SCRIPT 4: LÓGICA DE NEGOCIO (PROGRAMMABILITY)
-- Componentes: Funciones Definidas por el Usuario (UDF) y Stored Procedures
-- ==================================================================

USE educacion_chile_2023;

-- ==================================================================
-- SECCIÓN A: FUNCIONES ESCALARES (Cálculos matemáticos puros)
-- ==================================================================

-- 1. Cálculo del Costo Estimado Total de la Carrera
-- Lógica: ((Arancel + Matrícula) * Años de Duración) + Costo de Titulación
DROP FUNCTION IF EXISTS fn_calcular_costo_total;

DELIMITER //
CREATE FUNCTION fn_calcular_costo_total(
    p_arancel INT, 
    p_matricula INT, 
    p_titulacion INT, 
    p_semestres FLOAT
) 
RETURNS INT
DETERMINISTIC
BEGIN
    DECLARE v_duracion_anios FLOAT;
    DECLARE v_costo_total INT;

    -- Transformación analítica de granularidad: semestres a años académicos
    SET v_duracion_anios = p_semestres / 2;

    -- Amortización de costos anuales más el cobro único de titulación
    SET v_costo_total = ((p_arancel + p_matricula) * v_duracion_anios) + p_titulacion;

    RETURN v_costo_total;
END //
DELIMITER ;


-- 2. Estandarización de Etiquetas Geográficas
-- Evita la inconsistencia de cadenas de texto en los reportes operacionales.
DROP FUNCTION IF EXISTS fn_formato_sede_region;

DELIMITER //
CREATE FUNCTION fn_formato_sede_region(
    p_nombre_sede VARCHAR(255), 
    p_nombre_region VARCHAR(100)
)
RETURNS VARCHAR(300)
DETERMINISTIC
BEGIN
    RETURN CONCAT(UCASE(p_nombre_sede), ' - ', p_nombre_region); -- Forzado de mayúsculas para homogeneidad
END //
DELIMITER ;


-- ==================================================================
-- SECCIÓN B: PROCEDIMIENTOS ALMACENADOS (Operaciones y mutaciones)
-- ==================================================================

-- 1. Reporte Dinámico de Aranceles Máximos
DROP PROCEDURE IF EXISTS reporte_top_caras;

DELIMITER //
CREATE PROCEDURE reporte_top_caras(IN p_top_n INT)
BEGIN
    SELECT 
        c.carrera_generica,
        i.nombre_institucion,
        f.valor_arancel
    FROM fact_oferta f
    INNER JOIN dim_carrera c ON f.id_carrera_generica = c.id_carrera_generica
    INNER JOIN dim_institucion i ON f.id_institucion = i.id_institucion
    ORDER BY f.valor_arancel DESC
    LIMIT p_top_n;
END //
DELIMITER ;


-- 2. Inserción Segura de Instituciones (Prevención de duplicados)
DROP PROCEDURE IF EXISTS sp_insertar_institucion;

DELIMITER //
CREATE PROCEDURE sp_insertar_institucion(
    IN p_id INT,
    IN p_nombre VARCHAR(255),
    IN p_tipo VARCHAR(100)
)
BEGIN
    -- Validación preventiva contra errores de llave primaria (Error 1062)
    IF EXISTS (SELECT 1 FROM dim_institucion WHERE id_institucion = p_id) THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Error operativo: El ID de la Institución ya se encuentra registrado.';
    ELSE
        INSERT INTO dim_institucion (id_institucion, nombre_institucion, tipo_institucion, clasificacion1, clasificacion2, clasificacion3)
        VALUES (p_id, p_nombre, p_tipo, 'Sin Clasificación', 'N/A', 'N/A');
        
        SELECT CONCAT('Transacción exitosa: Institución "', p_nombre, '" guardada.') AS mensaje;
    END IF;
END //
DELIMITER ;


-- 3. Actualización Parametrizada de Sedes
DROP PROCEDURE IF EXISTS sp_actualizar_nombre_sede;

DELIMITER //
CREATE PROCEDURE sp_actualizar_nombre_sede(
    IN p_id_sede INT,
    IN p_nuevo_nombre VARCHAR(255)
)
BEGIN
    UPDATE dim_geografia
    SET nombre_sede = p_nuevo_nombre
    WHERE id_sede = p_id_sede;
    
    -- Retorno del registro modificado para auditoría inmediata
    SELECT id_sede, nombre_sede, comuna FROM dim_geografia WHERE id_sede = p_id_sede;
END //
DELIMITER ;


-- 4. Reporte Consolidado Regional con Consumo de Funciones
DROP PROCEDURE IF EXISTS sp_reporte_costos_region;

DELIMITER //
CREATE PROCEDURE sp_reporte_costos_region(IN p_region VARCHAR(100))
BEGIN
    SELECT 
        i.nombre_institucion,
        c.carrera_generica,
        fn_formato_sede_region(g.nombre_sede, g.nombre_region) AS ubicacion_completa,
        fn_calcular_costo_total(f.valor_arancel, f.valor_matricula, f.valor_titulo, f.duracion_semestres) AS costo_total_carrera
    FROM fact_oferta f
    INNER JOIN dim_institucion i ON f.id_institucion = i.id_institucion
    INNER JOIN dim_geografia g ON f.id_sede = g.id_sede
    INNER JOIN dim_carrera c ON f.id_carrera_generica = c.id_carrera_generica
    WHERE g.nombre_region = p_region
    ORDER BY costo_total_carrera DESC
    LIMIT 10;
END //
DELIMITER ;