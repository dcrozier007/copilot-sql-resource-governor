/*
================================================================================
    Schema Discovery Procedures for Demo Data Generation
    
    Purpose: Extract comprehensive database schema metadata for generating
             demo scripts, seeding data, and automating DBA processes
    
    Author: SQL Server Admin
    Date: 2026-08-17
    
    Procedures:
    - usp_get_database_schema
    - usp_get_table_metadata
    - usp_get_column_metadata
    - usp_get_constraint_metadata
    - usp_get_index_metadata
================================================================================
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

/* ============================================================================
   Procedure: usp_get_database_schema
   
   Purpose: Extract complete schema metadata from a database
   Returns: JSON formatted schema definition with all tables, columns, keys
   ============================================================================ */
CREATE OR ALTER PROCEDURE dbo.usp_get_database_schema
    @database_name sysname = NULL,
    @schema_name sysname = NULL,
    @table_name sysname = NULL,
    @output_format nvarchar(10) = 'JSON'
AS
BEGIN

    IF @database_name IS NULL
        SET @database_name = DB_NAME();

    IF @output_format NOT IN ('JSON', 'TABLE')
        SET @output_format = 'JSON';

    /* Temporary table to collect metadata */
    CREATE TABLE #schema_metadata
    (
        table_schema sysname,
        table_name sysname,
        column_name sysname,
        column_ordinal_position integer,
        data_type sysname,
        is_nullable bit,
        character_maximum_length integer,
        numeric_precision integer,
        numeric_scale integer,
        column_default nvarchar(max),
        is_identity bit,
        is_computed bit,
        computed_definition nvarchar(max),
        primary_key_name sysname,
        is_primary_key bit,
        unique_constraint_name sysname,
        is_unique bit,
        foreign_key_name sysname,
        referenced_table_schema sysname,
        referenced_table_name sysname,
        referenced_column_name sysname
    );

    /* Extract table and column metadata */
    INSERT INTO #schema_metadata
    SELECT
        table_schema = s.name,
        table_name = t.name,
        column_name = c.name,
        column_ordinal_position = c.column_id,
        data_type = typ.name,
        is_nullable = c.is_nullable,
        character_maximum_length = c.max_length,
        numeric_precision = c.precision,
        numeric_scale = c.scale,
        column_default = d.definition,
        is_identity = c.is_identity,
        is_computed = c.is_computed,
        computed_definition = cc.definition,
        primary_key_name = ISNULL(pk.name, ''),
        is_primary_key = CASE WHEN pk.name IS NOT NULL THEN 1 ELSE 0 END,
        unique_constraint_name = ISNULL(uc.name, ''),
        is_unique = CASE WHEN uc.name IS NOT NULL THEN 1 ELSE 0 END,
        foreign_key_name = ISNULL(fk.name, ''),
        referenced_table_schema = ISNULL(rs.name, ''),
        referenced_table_name = ISNULL(rt.name, ''),
        referenced_column_name = ISNULL(rc.name, '')
    FROM
        sys.tables AS t
        INNER JOIN sys.schemas AS s ON t.schema_id = s.schema_id
        INNER JOIN sys.columns AS c ON t.object_id = c.object_id
        LEFT JOIN sys.types AS typ ON c.user_type_id = typ.user_type_id
        LEFT JOIN sys.default_constraints AS d ON c.default_object_id = d.object_id
        LEFT JOIN sys.computed_columns AS cc ON c.object_id = cc.object_id AND c.column_id = cc.column_id
        LEFT JOIN sys.index_columns AS ic ON t.object_id = ic.object_id AND c.column_id = ic.column_id
        LEFT JOIN sys.indexes AS i ON ic.object_id = i.object_id AND ic.index_id = i.index_id AND i.is_primary_key = 1
        LEFT JOIN sys.key_constraints AS pk ON i.name = pk.name AND t.object_id = pk.parent_object_id AND pk.type = 'PK'
        LEFT JOIN sys.unique_constraints AS uc ON t.object_id = uc.parent_object_id
        LEFT JOIN sys.foreign_key_columns AS fkc ON c.object_id = fkc.parent_object_id AND c.column_id = fkc.parent_column_id
        LEFT JOIN sys.foreign_keys AS fk ON fkc.constraint_object_id = fk.object_id
        LEFT JOIN sys.tables AS rt ON fkc.referenced_object_id = rt.object_id
        LEFT JOIN sys.schemas AS rs ON rt.schema_id = rs.schema_id
        LEFT JOIN sys.columns AS rc ON fkc.referenced_object_id = rc.object_id AND fkc.referenced_column_id = rc.column_id
    WHERE
        s.name NOT IN ('sys', 'INFORMATION_SCHEMA')
        AND (
            @schema_name IS NULL
            OR s.name = @schema_name
        )
        AND (
            @table_name IS NULL
            OR t.name = @table_name
        );

    /* Return results based on format */
    IF @output_format = 'JSON'
    BEGIN
        SELECT
            json_output = JSON_QUERY(
                (
                    SELECT
                        table_schema,
                        table_name,
                        columns =
                        (
                            SELECT
                                column_name,
                                column_ordinal_position,
                                data_type,
                                is_nullable,
                                character_maximum_length,
                                numeric_precision,
                                numeric_scale,
                                column_default,
                                is_identity,
                                is_computed,
                                computed_definition,
                                primary_key_name,
                                is_primary_key,
                                unique_constraint_name,
                                is_unique,
                                foreign_key_name,
                                referenced_table_schema,
                                referenced_table_name,
                                referenced_column_name
                            FROM
                                #schema_metadata AS sm2
                            WHERE
                                sm2.table_schema = sm1.table_schema
                                AND sm2.table_name = sm1.table_name
                            FOR JSON PATH
                        )
                    FROM
                        (
                            SELECT DISTINCT
                                table_schema,
                                table_name
                            FROM
                                #schema_metadata
                        ) AS sm1
                    FOR JSON PATH
                )
            );
    END
    ELSE
    BEGIN
        SELECT
            *
        FROM
            #schema_metadata
        ORDER BY
            table_schema,
            table_name,
            column_ordinal_position;
    END

    DROP TABLE #schema_metadata;

END;

/* ============================================================================
   Procedure: usp_get_index_metadata
   
   Purpose: Extract index definitions for all tables
   Returns: Details about indexes, keys, and performance metadata
   ============================================================================ */
CREATE OR ALTER PROCEDURE dbo.usp_get_index_metadata
    @schema_name sysname = NULL,
    @table_name sysname = NULL
AS
BEGIN

    SELECT
        schema_name = s.name,
        table_name = t.name,
        index_name = i.name,
        index_type = i.type_desc,
        is_primary_key = i.is_primary_key,
        is_unique = i.is_unique,
        fill_factor = i.fill_factor,
        pad_index = i.pad_index,
        is_disabled = i.is_disabled,
        columns =
        (
            SELECT
                column_name,
                key_ordinal,
                is_included_column = ic.is_included_column
            FROM
                sys.index_columns AS ic
                INNER JOIN sys.columns AS c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
            WHERE
                ic.object_id = i.object_id
                AND ic.index_id = i.index_id
            ORDER BY
                ic.key_ordinal
            FOR JSON PATH
        )
    FROM
        sys.indexes AS i
        INNER JOIN sys.tables AS t ON i.object_id = t.object_id
        INNER JOIN sys.schemas AS s ON t.schema_id = s.schema_id
    WHERE
        i.index_id > 0
        AND s.name NOT IN ('sys', 'INFORMATION_SCHEMA')
        AND (
            @schema_name IS NULL
            OR s.name = @schema_name
        )
        AND (
            @table_name IS NULL
            OR t.name = @table_name
        )
    ORDER BY
        s.name,
        t.name,
        i.index_id;

END;

/* ============================================================================
   Procedure: usp_get_data_distribution
   
   Purpose: Get data distribution statistics for seeding realistic demo data
   Returns: Min/max values, cardinality, and sample data patterns
   ============================================================================ */
CREATE OR ALTER PROCEDURE dbo.usp_get_data_distribution
    @schema_name sysname,
    @table_name sysname
AS
BEGIN

    DECLARE
        @sql nvarchar(max),
        @column_list nvarchar(max);

    /* Build dynamic SQL to capture column statistics */
    SELECT
        @column_list = STRING_AGG(
            CASE
                WHEN typ.name IN ('int', 'bigint', 'smallint', 'tinyint', 'decimal', 'numeric', 'float', 'real')
                    THEN 'MIN(' + QUOTENAME(c.name) + ') AS ' + QUOTENAME(c.name + '_min') + ',' +
                         'MAX(' + QUOTENAME(c.name) + ') AS ' + QUOTENAME(c.name + '_max') + ',' +
                         'COUNT(DISTINCT ' + QUOTENAME(c.name) + ') AS ' + QUOTENAME(c.name + '_cardinality')
                WHEN typ.name IN ('varchar', 'nvarchar', 'char', 'nchar')
                    THEN 'MIN(LEN(' + QUOTENAME(c.name) + ')) AS ' + QUOTENAME(c.name + '_min_length') + ',' +
                         'MAX(LEN(' + QUOTENAME(c.name) + ')) AS ' + QUOTENAME(c.name + '_max_length') + ',' +
                         'COUNT(DISTINCT ' + QUOTENAME(c.name) + ') AS ' + QUOTENAME(c.name + '_cardinality')
                WHEN typ.name IN ('date', 'datetime', 'datetime2', 'datefromparts', 'smalldatetime')
                    THEN 'MIN(' + QUOTENAME(c.name) + ') AS ' + QUOTENAME(c.name + '_min_date') + ',' +
                         'MAX(' + QUOTENAME(c.name) + ') AS ' + QUOTENAME(c.name + '_max_date')
                ELSE ''
            END,
            ','
        )
    FROM
        sys.tables AS t
        INNER JOIN sys.schemas AS s ON t.schema_id = s.schema_id
        INNER JOIN sys.columns AS c ON t.object_id = c.object_id
        INNER JOIN sys.types AS typ ON c.user_type_id = typ.user_type_id
    WHERE
        s.name = @schema_name
        AND t.name = @table_name;

    IF @column_list IS NOT NULL
    BEGIN
        SET @sql = N'SELECT ' + @column_list + ' FROM ' + QUOTENAME(@schema_name) + N'.' + QUOTENAME(@table_name);

        EXECUTE sp_executesql @sql;
    END
    ELSE
    BEGIN
        RAISERROR('Table %s.%s not found or has no analyzable columns', 16, 1, @schema_name, @table_name);
    END

END;

PRINT 'Schema discovery procedures created successfully.';
