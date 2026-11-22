<#
================================================================================
    Master Orchestration Script - Demo Database Schema Discovery & Script Generation
    
    Purpose: Complete end-to-end workflow for extracting schema from multiple
             databases and generating demo/DBA scripts
    
    Usage:
        .\Generate-DemoScripts.ps1 -SqlInstance "SQLSERVER01" -Database "Demo" `
            -OutputPath "C:\DemoScripts"
    
    Author: SQL Server Admin
    Date: 2026-08-17
================================================================================
#>

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
    $Credential,

    [Parameter(Mandatory = $false)]
    [string]
    $SchemaFilter,

    [Parameter(Mandatory = $false)]
    [string]
    $TableFilter,

    [Parameter(Mandatory = $false)]
    [ValidateSet('All', 'Schema', 'Indexes', 'Seeding', 'Utilities')]
    [string]
    $ExportType = 'All',

    [Parameter(Mandatory = $false)]
    [int]
    $SeedRowCount = 100
)

$ErrorActionPreference = 'Stop'

<#
.DESCRIPTION
    Initialize the environment and load required modules
#>
function Initialize-Environment
{
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host "Demo Script Generation Workflow" -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host ""

    # Verify dbatools is installed
    if (-not (Get-Module -Name dbatools -ListAvailable))
    {
        Write-Host "Installing dbatools module..." -ForegroundColor Yellow
        Install-Module -Name dbatools -Force -AllowClobber
    }

    Import-Module -Name dbatools -Force

    # Import custom Schema-Discovery module
    $moduleRoot = Split-Path -Path $PSCommandPath -Parent
    $schemaModulePath = Join-Path -Path $moduleRoot -ChildPath "Schema-Discovery.psm1"

    if (Test-Path -Path $schemaModulePath)
    {
        Write-Host "Loading Schema-Discovery module..." -ForegroundColor Yellow
        Import-Module -Name $schemaModulePath -Force
    }
    else
    {
        Write-Error "Schema-Discovery.psm1 not found at: $schemaModulePath"
        exit 1
    }

    Write-Host "Environment initialized successfully`n" -ForegroundColor Green
}

<#
.DESCRIPTION
    Test connectivity to SQL Server instance and database
#>
function Test-DatabaseConnectivity
{
    Write-Host "Testing database connectivity..." -ForegroundColor Yellow

    try
    {
        $connectionParams = @{
            SqlInstance = $SqlInstance
            Database = $Database
            ErrorAction = 'Stop'
        }

        if ($Credential)
        {
            $connectionParams['SqlCredential'] = $Credential
        }

        $testQuery = Invoke-DbaQuery @connectionParams -Query "SELECT 'Connection successful' AS result"

        if ($testQuery)
        {
            Write-Host "Connected to $SqlInstance\$Database" -ForegroundColor Green
            return $true
        }
    }
    catch
    {
        Write-Error "Failed to connect to database: $_"
        return $false
    }
}

<#
.DESCRIPTION
    Create output directory structure
#>
function New-OutputDirectory
{
    Write-Host "Creating output directories..." -ForegroundColor Yellow

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $outputRoot = Join-Path -Path $OutputPath -ChildPath "$Database-$timestamp"

    $directories = @(
        "Schema",
        "Seeding",
        "Utilities",
        "Analysis",
        "Logs"
    )

    foreach ($dir in $directories)
    {
        $dirPath = Join-Path -Path $outputRoot -ChildPath $dir
        New-Item -ItemType Directory -Path $dirPath -Force | Out-Null
    }

    Write-Host "Output directory created: $outputRoot`n" -ForegroundColor Green
    return $outputRoot
}

<#
.DESCRIPTION
    Extract and export schema metadata
#>
function Export-Schema
{
    param([string]$OutputDir)

    Write-Host "Exporting schema metadata..." -ForegroundColor Yellow

    $schemaPath = Join-Path -Path $OutputDir -ChildPath "Schema"
    $exportFile = Join-Path -Path $schemaPath -ChildPath "database-schema.json"

    try
    {
        $params = @{
            SqlInstance = $SqlInstance
            Database = $Database
            OutputPath = $exportFile
        }

        if ($Credential)
        {
            $params['Credential'] = $Credential
        }

        Export-SchemaMetadata @params

        # Also export in TABLE format for readability
        $tableExportFile = Join-Path -Path $schemaPath -ChildPath "database-schema-table.csv"
        
        $connectionParams = @{
            SqlInstance = $SqlInstance
            Database = $Database
        }

        if ($Credential)
        {
            $connectionParams['SqlCredential'] = $Credential
        }

        $schemaTable = Get-DatabaseSchema @connectionParams -OutputFormat TABLE
        $schemaTable | Export-Csv -Path $tableExportFile -NoTypeInformation

        Write-Host "Schema exported to:`n  - $exportFile`n  - $tableExportFile`n" -ForegroundColor Green

        return $exportFile
    }
    catch
    {
        Write-Error "Failed to export schema: $_"
        throw
    }
}

<#
.DESCRIPTION
    Export index metadata
#>
function Export-Indexes
{
    param([string]$OutputDir)

    Write-Host "Exporting index metadata..." -ForegroundColor Yellow

    $schemaPath = Join-Path -Path $OutputDir -ChildPath "Schema"
    $exportFile = Join-Path -Path $schemaPath -ChildPath "index-metadata.csv"

    try
    {
        $connectionParams = @{
            SqlInstance = $SqlInstance
            Database = $Database
        }

        if ($Credential)
        {
            $connectionParams['SqlCredential'] = $Credential
        }

        if ($SchemaFilter)
        {
            $connectionParams['SchemaName'] = $SchemaFilter
        }

        if ($TableFilter)
        {
            $connectionParams['TableName'] = $TableFilter
        }

        $indexData = Get-IndexMetadata @connectionParams
        $indexData | Export-Csv -Path $exportFile -NoTypeInformation

        Write-Host "Index metadata exported to: $exportFile`n" -ForegroundColor Green

        return $exportFile
    }
    catch
    {
        Write-Error "Failed to export indexes: $_"
        throw
    }
}

<#
.DESCRIPTION
    Generate data seeding scripts
#>
function Generate-SeedingScripts
{
    param([string]$OutputDir, [string]$SchemaFile)

    Write-Host "Generating data seeding scripts..." -ForegroundColor Yellow

    $seedingPath = Join-Path -Path $OutputDir -ChildPath "Seeding"

    try
    {
        if (-not (Test-Path -Path $SchemaFile))
        {
            Write-Error "Schema file not found: $SchemaFile"
            return
        }

        $schema = Get-Content -Path $SchemaFile | ConvertFrom-Json

        $tableCount = 0
        foreach ($table in $schema)
        {
            $scriptPath = Join-Path -Path $seedingPath -ChildPath "Seed-$($table.table_name).sql"

            New-DataSeedingScript -SchemaObject $schema -TableName $table.table_name `
                -RowCount $SeedRowCount -OutputPath $scriptPath

            $tableCount++
        }

        Write-Host "Generated $tableCount seeding scripts in: $seedingPath`n" -ForegroundColor Green
    }
    catch
    {
        Write-Error "Failed to generate seeding scripts: $_"
        throw
    }
}

<#
.DESCRIPTION
    Generate DBA utility scripts
#>
function Generate-UtilityScripts
{
    param([string]$OutputDir)

    Write-Host "Generating DBA utility scripts..." -ForegroundColor Yellow

    $utilityPath = Join-Path -Path $OutputDir -ChildPath "Utilities"
    $utilityTypes = @('Backup', 'IndexMaintenance', 'Statistics', 'Monitoring')

    try
    {
        foreach ($utility in $utilityTypes)
        {
            $scriptPath = Join-Path -Path $utilityPath -ChildPath "$utility-Utilities.sql"
            New-DBAUtilityScript -Database $Database -UtilityType $utility -OutputPath $scriptPath
        }

        Write-Host "Generated utility scripts in: $utilityPath`n" -ForegroundColor Green
    }
    catch
    {
        Write-Error "Failed to generate utility scripts: $_"
        throw
    }
}

<#
.DESCRIPTION
    Generate summary report
#>
function New-SummaryReport
{
    param([string]$OutputDir, [string]$SchemaFile)

    Write-Host "Generating summary report..." -ForegroundColor Yellow

    $reportPath = Join-Path -Path $OutputDir -ChildPath "Logs\execution-summary.txt"

    try
    {
        $schema = Get-Content -Path $SchemaFile | ConvertFrom-Json
        $tableCount = ($schema | Measure-Object).Count

        $report = @"
================================================================================
            DEMO SCRIPT GENERATION EXECUTION SUMMARY
================================================================================

Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
SQL Instance: $SqlInstance
Database: $Database
Export Type: $ExportType

================================================================================
EXTRACTION RESULTS
================================================================================

Tables Analyzed: $tableCount
Seed Row Count: $SeedRowCount
Schema Filter: $(if ($SchemaFilter) { $SchemaFilter } else { 'None (all schemas)' })
Table Filter: $(if ($TableFilter) { $TableFilter } else { 'None (all tables)' })

================================================================================
GENERATED ARTIFACTS
================================================================================

Output Directory: $OutputDir

Generated Files:
  - Schema metadata (JSON): database-schema.json
  - Schema metadata (CSV): database-schema-table.csv
  - Index metadata: index-metadata.csv
  - Data seeding scripts: Seeding/Seed-*.sql
  - DBA utility scripts:
    * Backup-Utilities.sql
    * IndexMaintenance-Utilities.sql
    * Statistics-Utilities.sql
    * Monitoring-Utilities.sql

================================================================================
NEXT STEPS
================================================================================

1. Review generated schema files:
   - Examine database-schema.json for complete structure
   - Check index-metadata.csv for performance analysis

2. Customize data seeding scripts:
   - Edit Seeding/Seed-*.sql scripts
   - Add realistic data generation logic
   - Adjust row counts as needed

3. Deploy utility scripts:
   - Review DBA scripts for your environment
   - Modify backup paths, email recipients, etc.
   - Create SQL Agent jobs for automation

4. Execute scripts:
   - Validate scripts against target database
   - Test in development environment first
   - Schedule jobs for regular execution

================================================================================
"@

        $report | Out-File -FilePath $reportPath -Encoding UTF8

        Write-Host "Summary report created: $reportPath`n" -ForegroundColor Green
    }
    catch
    {
        Write-Error "Failed to generate summary report: $_"
    }
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

try
{
    Initialize-Environment

    if (-not (Test-DatabaseConnectivity))
    {
        exit 1
    }

    $outputDir = New-OutputDirectory

    switch ($ExportType)
    {
        'All'
        {
            $schemaFile = Export-Schema -OutputDir $outputDir
            Export-Indexes -OutputDir $outputDir
            Generate-SeedingScripts -OutputDir $outputDir -SchemaFile $schemaFile
            Generate-UtilityScripts -OutputDir $outputDir
            New-SummaryReport -OutputDir $outputDir -SchemaFile $schemaFile
        }
        'Schema'
        {
            $schemaFile = Export-Schema -OutputDir $outputDir
            New-SummaryReport -OutputDir $outputDir -SchemaFile $schemaFile
        }
        'Indexes'
        {
            Export-Indexes -OutputDir $outputDir
        }
        'Seeding'
        {
            $schemaFile = Export-Schema -OutputDir $outputDir
            Generate-SeedingScripts -OutputDir $outputDir -SchemaFile $schemaFile
        }
        'Utilities'
        {
            Generate-UtilityScripts -OutputDir $outputDir
        }
    }

    Write-Host "================================" -ForegroundColor Green
    Write-Host "Workflow Completed Successfully" -ForegroundColor Green
    Write-Host "================================" -ForegroundColor Green
    Write-Host "Output Directory: $outputDir" -ForegroundColor Cyan
}
catch
{
    Write-Error "Workflow failed: $_"
    exit 1
}
