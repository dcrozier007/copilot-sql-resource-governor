<#
================================================================================
    Schema Discovery and Metadata Export Module
    
    Purpose: PowerShell-based orchestration for extracting database schema
             metadata across multiple SQL Server instances and databases
    
    Author: SQL Server Admin
    Date: 2026-08-17
    
    Functions:
    - Get-DatabaseSchema
    - Get-IndexMetadata
    - Get-DataDistribution
    - Export-SchemaMetadata
    - New-DataSeedingScript
    - New-DBAUtilityScript
================================================================================
#>

#Requires -Version 5.1
#Requires -Modules dbatools

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'SilentlyContinue'

<#
.SYNOPSIS
    Extracts complete database schema metadata from SQL Server.

.DESCRIPTION
    Connects to a SQL Server instance and database, then executes schema
    discovery procedures to extract comprehensive metadata about tables,
    columns, keys, constraints, and indexes.

.PARAMETER SqlInstance
    SQL Server instance name or IP address.

.PARAMETER Database
    Database name to analyze.

.PARAMETER Credential
    PSCredential object for SQL Server authentication (optional for Windows auth).

.PARAMETER SchemaName
    Specific schema to analyze (optional, default: all non-system schemas).

.PARAMETER TableName
    Specific table to analyze (optional, default: all tables).

.PARAMETER OutputFormat
    Format for results: 'JSON' or 'TABLE' (default: 'JSON').

.EXAMPLE
    $schema = Get-DatabaseSchema -SqlInstance "SQLSERVER01" -Database "Demo" -OutputFormat JSON
    
.NOTES
    Requires dbatools module and appropriate SQL Server permissions.
#>
function Get-DatabaseSchema
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $SqlInstance,

        [Parameter(Mandatory = $true)]
        [string]
        $Database,

        [Parameter(Mandatory = $false)]
        [pscredential]
        $Credential,

        [Parameter(Mandatory = $false)]
        [string]
        $SchemaName,

        [Parameter(Mandatory = $false)]
        [string]
        $TableName,

        [Parameter(Mandatory = $false)]
        [ValidateSet('JSON', 'TABLE')]
        [string]
        $OutputFormat = 'JSON'
    )

    try
    {
        Write-Verbose "Connecting to $SqlInstance\$Database..."

        $connection = @{
            SqlInstance = $SqlInstance
            Database = $Database
        }

        if ($Credential)
        {
            $connection['SqlCredential'] = $Credential
        }

        $params = @{
            Query = @"
EXECUTE dbo.usp_get_database_schema
    @schema_name = $(if ($SchemaName) { "'$SchemaName'" } else { 'NULL' }),
    @table_name = $(if ($TableName) { "'$TableName'" } else { 'NULL' }),
    @output_format = '$OutputFormat'
"@
        }
        $connection.Keys | ForEach-Object { $params[$_] = $connection[$_] }

        $result = Invoke-DbaQuery @params

        if ($OutputFormat -eq 'JSON')
        {
            $result.json_output | ConvertFrom-Json
        }
        else
        {
            $result
        }
    }
    catch
    {
        Write-Error "Failed to retrieve schema metadata: $_"
        throw
    }
}

<#
.SYNOPSIS
    Extracts index metadata from specified database.

.DESCRIPTION
    Retrieves detailed information about all indexes, including primary keys,
    unique constraints, and included columns for query optimization analysis.

.PARAMETER SqlInstance
    SQL Server instance name or IP address.

.PARAMETER Database
    Database name to analyze.

.PARAMETER Credential
    PSCredential object for SQL Server authentication (optional).

.PARAMETER SchemaName
    Specific schema to analyze (optional).

.PARAMETER TableName
    Specific table to analyze (optional).

.EXAMPLE
    $indexes = Get-IndexMetadata -SqlInstance "SQLSERVER01" -Database "Demo"
    
#>
function Get-IndexMetadata
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $SqlInstance,

        [Parameter(Mandatory = $true)]
        [string]
        $Database,

        [Parameter(Mandatory = $false)]
        [pscredential]
        $Credential,

        [Parameter(Mandatory = $false)]
        [string]
        $SchemaName,

        [Parameter(Mandatory = $false)]
        [string]
        $TableName
    )

    try
    {
        Write-Verbose "Retrieving index metadata from $SqlInstance\$Database..."

        $connection = @{
            SqlInstance = $SqlInstance
            Database = $Database
            Query = @"
EXECUTE dbo.usp_get_index_metadata
    @schema_name = $(if ($SchemaName) { "'$SchemaName'" } else { 'NULL' }),
    @table_name = $(if ($TableName) { "'$TableName'" } else { 'NULL' })
"@
        }

        if ($Credential)
        {
            $connection['SqlCredential'] = $Credential
        }

        Invoke-DbaQuery @connection
    }
    catch
    {
        Write-Error "Failed to retrieve index metadata: $_"
        throw
    }
}

<#
.SYNOPSIS
    Exports schema metadata to JSON file for processing.

.DESCRIPTION
    Retrieves complete schema metadata and exports to a structured JSON file
    that can be used by downstream script generators.

.PARAMETER SqlInstance
    SQL Server instance name.

.PARAMETER Database
    Database name.

.PARAMETER OutputPath
    File path for JSON export.

.PARAMETER Credential
    PSCredential object for SQL Server authentication (optional).

.EXAMPLE
    Export-SchemaMetadata -SqlInstance "SQLSERVER01" -Database "Demo" `
        -OutputPath "C:\Schemas\Demo-schema.json"
    
#>
function Export-SchemaMetadata
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $SqlInstance,

        [Parameter(Mandatory = $true)]
        [string]
        $Database,

        [Parameter(Mandatory = $true)]
        [string]
        $OutputPath,

        [Parameter(Mandatory = $false)]
        [pscredential]
        $Credential
    )

    try
    {
        Write-Verbose "Exporting schema metadata for $Database..."

        $params = @{
            SqlInstance = $SqlInstance
            Database = $Database
        }

        if ($Credential)
        {
            $params['Credential'] = $Credential
        }

        $schema = Get-DatabaseSchema @params -OutputFormat JSON

        $schema | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputPath -Encoding UTF8

        Write-Host "Schema exported to: $OutputPath" -ForegroundColor Green
        return $OutputPath
    }
    catch
    {
        Write-Error "Failed to export schema metadata: $_"
        throw
    }
}

<#
.SYNOPSIS
    Generates a T-SQL script for seeding demo data into specified table.

.DESCRIPTION
    Analyzes table structure and data types, then generates INSERT statements
    for populating demo/test data. Uses Faker patterns for realistic data.

.PARAMETER SchemaObject
    Schema metadata object (from Get-DatabaseSchema).

.PARAMETER TableName
    Table to generate seeding script for.

.PARAMETER RowCount
    Number of rows to generate (default: 100).

.PARAMETER OutputPath
    File path for script output.

.EXAMPLE
    New-DataSeedingScript -SchemaObject $schema -TableName "Customer" `
        -RowCount 500 -OutputPath "C:\Scripts\Seed-Customer.sql"
    
#>
function New-DataSeedingScript
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [object]
        $SchemaObject,

        [Parameter(Mandatory = $true)]
        [string]
        $TableName,

        [Parameter(Mandatory = $false)]
        [int]
        $RowCount = 100,

        [Parameter(Mandatory = $true)]
        [string]
        $OutputPath
    )

    try
    {
        Write-Verbose "Generating data seeding script for $TableName..."

        $table = $SchemaObject | Where-Object { $_.table_name -eq $TableName } | Select-Object -First 1

        if (-not $table)
        {
            throw "Table $TableName not found in schema metadata"
        }

        $columns = $table.columns | ConvertFrom-Json

        $sqlScript = @"
/*
================================================================================
    Auto-Generated Data Seeding Script
    Table: [$($table.table_schema)].[$TableName]
    Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    Row Count: $RowCount
================================================================================
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRANSACTION;

BEGIN TRY
    /* Disable constraints for bulk insert */
    ALTER TABLE [$($table.table_schema)].[$TableName] NOCHECK CONSTRAINT ALL;

    /* Generate and insert demo data */
    /* TODO: Customize seed data logic based on column data types */
    
    DECLARE @counter integer = 1;
    
    WHILE @counter <= $RowCount
    BEGIN
        INSERT INTO [$($table.table_schema)].[$TableName]
        (
"@

        # Add column names
        $columnNames = @()
        foreach ($column in $columns)
        {
            if (-not $column.is_identity)
            {
                $columnNames += "            [$($column.column_name)]"
            }
        }
        $sqlScript += $columnNames -join ",`r`n"

        $sqlScript += @"
        )
        VALUES
        (
            /* TODO: Add values for each column */
        );
        
        SET @counter = @counter + 1;
    END

    /* Re-enable constraints */
    ALTER TABLE [$($table.table_schema)].[$TableName] CHECK CONSTRAINT ALL;

    COMMIT TRANSACTION;
    PRINT 'Successfully inserted $RowCount rows into [$($table.table_schema)].[$TableName]';
END TRY
BEGIN CATCH
    ROLLBACK TRANSACTION;
    DECLARE @error_message nvarchar(max) = ERROR_MESSAGE();
    RAISERROR('Error seeding data: %s', 16, 1, @error_message);
END CATCH
"@

        $sqlScript | Out-File -FilePath $OutputPath -Encoding UTF8

        Write-Host "Data seeding script generated: $OutputPath" -ForegroundColor Green
        return $OutputPath
    }
    catch
    {
        Write-Error "Failed to generate data seeding script: $_"
        throw
    }
}

<#
.SYNOPSIS
    Generates a T-SQL DBA utility script for maintenance tasks.

.DESCRIPTION
    Creates reusable T-SQL procedures for common DBA operations:
    - Backup jobs
    - Index maintenance
    - Statistics updates
    - Job monitoring

.PARAMETER Database
    Database name.

.PARAMETER UtilityType
    Type of utility: 'Backup', 'IndexMaintenance', 'Statistics', 'Monitoring'

.PARAMETER OutputPath
    File path for script output.

.EXAMPLE
    New-DBAUtilityScript -Database "Demo" -UtilityType "IndexMaintenance" `
        -OutputPath "C:\Scripts\Maintain-Indexes.sql"
    
#>
function New-DBAUtilityScript
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $Database,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Backup', 'IndexMaintenance', 'Statistics', 'Monitoring')]
        [string]
        $UtilityType,

        [Parameter(Mandatory = $true)]
        [string]
        $OutputPath
    )

    try
    {
        Write-Verbose "Generating $UtilityType DBA utility script for $Database..."

        $sqlScript = @"
/*
================================================================================
    Auto-Generated DBA Utility Script
    Utility Type: $UtilityType
    Database: $Database
    Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
================================================================================
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

"@

        switch ($UtilityType)
        {
            'Backup'
            {
                $sqlScript += @"
/* ============================================================================
   Backup Procedure
   
   Purpose: Complete backup of all database filegroups
   ============================================================================ */

CREATE OR ALTER PROCEDURE dbo.usp_backup_database
    @backup_path nvarchar(260),
    @backup_type varchar(10) = 'FULL'
AS
BEGIN
    DECLARE
        @backup_file nvarchar(260),
        @backup_name nvarchar(128);

    SET @backup_name = '$Database-' + FORMAT(GETDATE(), 'yyyyMMdd-HHmmss');
    SET @backup_file = @backup_path + @backup_name + '.bak';

    BEGIN TRY
        BACKUP DATABASE [$Database]
        TO DISK = @backup_file
        WITH
            FORMAT,
            INIT,
            NAME = @backup_name,
            STATS = 10,
            COMPRESSION;

        PRINT 'Backup completed successfully: ' + @backup_file;
    END TRY
    BEGIN CATCH
        DECLARE @error_message nvarchar(max) = ERROR_MESSAGE();
        RAISERROR('Backup failed: %s', 16, 1, @error_message);
    END CATCH
END;
"@
            }
            'IndexMaintenance'
            {
                $sqlScript += @"
/* ============================================================================
   Index Maintenance Procedure
   
   Purpose: Rebuild or reorganize fragmented indexes
   ============================================================================ */

CREATE OR ALTER PROCEDURE dbo.usp_maintain_indexes
    @fragmentation_threshold_rebuild numeric(5, 2) = 30.0,
    @fragmentation_threshold_reorganize numeric(5, 2) = 10.0,
    @debug bit = 0
AS
BEGIN
    DECLARE
        @table_name sysname,
        @index_name sysname,
        @fragmentation numeric(5, 2),
        @sql nvarchar(max);

    DECLARE index_cursor CURSOR FOR
        SELECT
            t.name,
            i.name,
            ps.avg_fragmentation_in_percent
        FROM
            sys.indexes AS i
            INNER JOIN sys.tables AS t ON i.object_id = t.object_id
            INNER JOIN sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') AS ps
                ON i.object_id = ps.object_id
                AND i.index_id = ps.index_id
        WHERE
            ps.avg_fragmentation_in_percent > @fragmentation_threshold_reorganize
            AND i.index_id > 0
        ORDER BY
            ps.avg_fragmentation_in_percent DESC;

    OPEN index_cursor;

    FETCH NEXT FROM index_cursor INTO @table_name, @index_name, @fragmentation;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF @fragmentation > @fragmentation_threshold_rebuild
        BEGIN
            SET @sql = 'ALTER INDEX ' + QUOTENAME(@index_name) + ' ON dbo.' + QUOTENAME(@table_name) + ' REBUILD;';
            IF @debug = 1
                PRINT @sql;
            ELSE
                EXECUTE sp_executesql @sql;
        END
        ELSE
        BEGIN
            SET @sql = 'ALTER INDEX ' + QUOTENAME(@index_name) + ' ON dbo.' + QUOTENAME(@table_name) + ' REORGANIZE;';
            IF @debug = 1
                PRINT @sql;
            ELSE
                EXECUTE sp_executesql @sql;
        END

        FETCH NEXT FROM index_cursor INTO @table_name, @index_name, @fragmentation;
    END

    CLOSE index_cursor;
    DEALLOCATE index_cursor;

    PRINT 'Index maintenance completed.';
END;
"@
            }
            'Statistics'
            {
                $sqlScript += @"
/* ============================================================================
   Statistics Update Procedure
   
   Purpose: Update statistics for query optimization
   ============================================================================ */

CREATE OR ALTER PROCEDURE dbo.usp_update_statistics
    @sample_percent integer = NULL,
    @debug bit = 0
AS
BEGIN
    DECLARE
        @sql nvarchar(max),
        @stat_name sysname,
        @table_name sysname;

    DECLARE stats_cursor CURSOR FOR
        SELECT
            s.name,
            t.name
        FROM
            sys.stats AS s
            INNER JOIN sys.tables AS t ON s.object_id = t.object_id
        WHERE
            t.schema_id = SCHEMA_ID('dbo');

    OPEN stats_cursor;

    FETCH NEXT FROM stats_cursor INTO @stat_name, @table_name;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @sql = 'UPDATE STATISTICS dbo.' + QUOTENAME(@table_name) + 
                   ' ' + QUOTENAME(@stat_name);
        
        IF @sample_percent IS NOT NULL
            SET @sql = @sql + ' WITH SAMPLE ' + CAST(@sample_percent AS varchar(3)) + ' PERCENT';

        IF @debug = 1
            PRINT @sql;
        ELSE
            EXECUTE sp_executesql @sql;

        FETCH NEXT FROM stats_cursor INTO @stat_name, @table_name;
    END

    CLOSE stats_cursor;
    DEALLOCATE stats_cursor;

    PRINT 'Statistics update completed.';
END;
"@
            }
            'Monitoring'
            {
                $sqlScript += @"
/* ============================================================================
   Database Monitoring Procedure
   
   Purpose: Collect and report on database health metrics
   ============================================================================ */

CREATE OR ALTER PROCEDURE dbo.usp_monitor_database
AS
BEGIN
    SELECT
        database_name = DB_NAME(),
        capture_time = GETDATE(),
        table_count = (SELECT COUNT(*) FROM sys.tables WHERE schema_id != SCHEMA_ID('INFORMATION_SCHEMA')),
        index_count = (SELECT COUNT(*) FROM sys.indexes WHERE index_id > 0),
        total_size_mb = (
            SELECT
                CONVERT(numeric(15, 2), SUM(size) * 8.0 / 1024)
            FROM
                sys.database_files
        ),
        used_space_mb = (
            SELECT
                CONVERT(numeric(15, 2), SUM(CAST(FILEPROPERTY(name, 'SpaceUsed') AS bigint)) * 8.0 / 1024)
            FROM
                sys.database_files
            WHERE
                type_desc = 'ROWS'
        ),
        log_size_mb = (
            SELECT
                CONVERT(numeric(15, 2), SUM(size) * 8.0 / 1024)
            FROM
                sys.database_files
            WHERE
                type_desc = 'LOG'
        ),
        growth_trigger_tables = (
            SELECT
                COUNT(*)
            FROM
                sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED')
            WHERE
                avg_fragmentation_in_percent > 10
                AND index_id > 0
        );
END;
"@
            }
        }

        $sqlScript | Out-File -FilePath $OutputPath -Encoding UTF8

        Write-Host "$UtilityType utility script generated: $OutputPath" -ForegroundColor Green
        return $OutputPath
    }
    catch
    {
        Write-Error "Failed to generate DBA utility script: $_"
        throw
    }
}

<#
.SYNOPSIS
    Generates multiple demo scripts for a database.

.DESCRIPTION
    Orchestrates generation of all types of demo scripts based on
    exported schema metadata.

.PARAMETER SchemaMetadataPath
    Path to exported schema JSON file.

.PARAMETER OutputDirectory
    Directory for generated scripts.

.PARAMETER Generate
    Types of scripts to generate: 'DataSeeding', 'Utilities', 'All' (default: 'All')

.EXAMPLE
    Invoke-SchemaScriptGeneration -SchemaMetadataPath "C:\Schemas\Demo.json" `
        -OutputDirectory "C:\Scripts\Generated" -Generate "All"
    
#>
function Invoke-SchemaScriptGeneration
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $SchemaMetadataPath,

        [Parameter(Mandatory = $true)]
        [string]
        $OutputDirectory,

        [Parameter(Mandatory = $false)]
        [ValidateSet('DataSeeding', 'Utilities', 'All')]
        [string]
        $Generate = 'All'
    )

    try
    {
        Write-Verbose "Loading schema metadata from $SchemaMetadataPath..."

        if (-not (Test-Path -Path $SchemaMetadataPath))
        {
            throw "Schema metadata file not found: $SchemaMetadataPath"
        }

        $schema = Get-Content -Path $SchemaMetadataPath | ConvertFrom-Json

        if (-not (Test-Path -Path $OutputDirectory))
        {
            New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
        }

        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $generateDir = Join-Path -Path $OutputDirectory -ChildPath "Generated-$timestamp"
        New-Item -ItemType Directory -Path $generateDir -Force | Out-Null

        Write-Host "Generating scripts in: $generateDir" -ForegroundColor Cyan

        if ($Generate -in @('DataSeeding', 'All'))
        {
            Write-Host "Generating data seeding scripts..." -ForegroundColor Yellow
            foreach ($table in $schema.table_name)
            {
                $scriptPath = Join-Path -Path $generateDir -ChildPath "Seed-$table.sql"
                New-DataSeedingScript -SchemaObject $schema -TableName $table `
                    -RowCount 100 -OutputPath $scriptPath
            }
        }

        if ($Generate -in @('Utilities', 'All'))
        {
            Write-Host "Generating DBA utility scripts..." -ForegroundColor Yellow
            $utilityTypes = @('Backup', 'IndexMaintenance', 'Statistics', 'Monitoring')
            $database = (Split-Path -Leaf $SchemaMetadataPath).Replace('.json', '')

            foreach ($utility in $utilityTypes)
            {
                $scriptPath = Join-Path -Path $generateDir -ChildPath "$utility-Utilities.sql"
                New-DBAUtilityScript -Database $database -UtilityType $utility `
                    -OutputPath $scriptPath
            }
        }

        Write-Host "Script generation completed: $generateDir" -ForegroundColor Green
        return $generateDir
    }
    catch
    {
        Write-Error "Failed to generate scripts: $_"
        throw
    }
}

Export-ModuleMember -Function @(
    'Get-DatabaseSchema',
    'Get-IndexMetadata',
    'Get-DataDistribution',
    'Export-SchemaMetadata',
    'New-DataSeedingScript',
    'New-DBAUtilityScript',
    'Invoke-SchemaScriptGeneration'
)
