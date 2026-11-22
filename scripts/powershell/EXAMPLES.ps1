<#
================================================================================
    EXAMPLE USAGE: Complete Workflow Demonstrations
    
    This file shows practical examples of using the Schema Discovery Framework
    for various scenarios.
    
    Author: SQL Server Admin
    Date: 2026-08-17
================================================================================
#>

<#
================================================================================
    EXAMPLE 1: Basic Full Workflow
    
    Scenario: First time setup for a new demo database
    Output: All scripts (schema, seeding, utilities)
================================================================================
#>

# Example 1: One-line complete workflow
Write-Host "Example 1: Complete Workflow" -ForegroundColor Cyan
Write-Host "=============================" -ForegroundColor Cyan

$workflowParams = @{
    SqlInstance = "SQLSERVER01"
    Database = "Demo"
    OutputPath = "C:\DemoScripts"
    ExportType = "All"
    SeedRowCount = 1000
}

<#
# Uncomment to run:
& ".\scripts\powershell\Generate-DemoScripts.ps1" @workflowParams
#>


<#
================================================================================
    EXAMPLE 2: Schema-Only Export with Filtering
    
    Scenario: Extract schema from specific schema/tables only
================================================================================
#>

Write-Host "`nExample 2: Filtered Schema Export" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan

# Load module
Import-Module -Path ".\scripts\powershell\Schema-Discovery.psm1" -Force

# Export only Sales schema
$salesSchema = Get-DatabaseSchema `
    -SqlInstance "SQLSERVER01" `
    -Database "Demo" `
    -SchemaName "Sales" `
    -OutputFormat JSON

# Export to file
$salesSchema | ConvertTo-Json -Depth 10 | Out-File "C:\Schemas\Sales-Schema.json"

Write-Host "Sales schema exported to: C:\Schemas\Sales-Schema.json" -ForegroundColor Green


<#
================================================================================
    EXAMPLE 3: Index Analysis and Reporting
    
    Scenario: Analyze indexes for performance tuning
================================================================================
#>

Write-Host "`nExample 3: Index Analysis" -ForegroundColor Cyan
Write-Host "==========================" -ForegroundColor Cyan

# Get index metadata for specific table
$indexes = Get-IndexMetadata `
    -SqlInstance "SQLSERVER01" `
    -Database "Demo" `
    -TableName "Order"

# Export to CSV for analysis
$indexes | Export-Csv -Path "C:\Reports\Order-Indexes.csv" -NoTypeInformation

# Display summary
Write-Host "Indexes on Order table:"
$indexes | Select-Object index_name, index_type, is_primary_key, is_unique | Format-Table

Write-Host "Report saved to: C:\Reports\Order-Indexes.csv" -ForegroundColor Green


<#
================================================================================
    EXAMPLE 4: Data Distribution Analysis
    
    Scenario: Get column statistics for realistic demo data generation
================================================================================
#>

Write-Host "`nExample 4: Data Distribution Analysis" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan

# Get data distribution for specific table
$distribution = Get-DataDistribution `
    -SqlInstance "SQLSERVER01" `
    -Database "Demo" `
    -Credential (Get-Credential)

Write-Host "Data Distribution for Order table:" -ForegroundColor Yellow
$distribution | Format-Table

# Export results
$distribution | Export-Csv -Path "C:\Reports\Order-Distribution.csv" -NoTypeInformation


<#
================================================================================
    EXAMPLE 5: Generate Single Seeding Script
    
    Scenario: Create INSERT template for specific table
================================================================================
#>

Write-Host "`nExample 5: Generate Single Seeding Script" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# Load schema
$schema = Get-Content "C:\Schemas\Demo-schema.json" | ConvertFrom-Json

# Generate seeding script for Customer table
$seedScript = New-DataSeedingScript `
    -SchemaObject $schema `
    -TableName "Customer" `
    -RowCount 500 `
    -OutputPath "C:\Scripts\Seed-Customer.sql"

Write-Host "Seeding script created: $seedScript" -ForegroundColor Green

# Show first part of generated script
Write-Host "`nGenerated script preview:"
Get-Content $seedScript -TotalCount 50 | Write-Host


<#
================================================================================
    EXAMPLE 6: Generate DBA Utility Scripts
    
    Scenario: Create automation scripts for index maintenance
================================================================================
#>

Write-Host "`nExample 6: Generate DBA Utility Scripts" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan

# Generate all utility types
$utilities = @('Backup', 'IndexMaintenance', 'Statistics', 'Monitoring')

foreach ($utility in $utilities)
{
    $scriptPath = "C:\Scripts\$utility-Utilities.sql"
    
    $utilScript = New-DBAUtilityScript `
        -Database "Demo" `
        -UtilityType $utility `
        -OutputPath $scriptPath
    
    Write-Host "$utility utility created: $scriptPath" -ForegroundColor Green
}


<#
================================================================================
    EXAMPLE 7: Multi-Database Batch Processing
    
    Scenario: Extract schema from multiple databases in one operation
================================================================================
#>

Write-Host "`nExample 7: Multi-Database Batch Processing" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan

$databases = @("Demo", "Test", "Staging", "Production")
$instanceName = "SQLSERVER01"
$baseOutput = "C:\DemoScripts"

foreach ($db in $databases)
{
    Write-Host "Processing: $db" -ForegroundColor Yellow
    
    $outputDir = Join-Path -Path $baseOutput -ChildPath $db
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    
    # Export schema for each database
    Export-SchemaMetadata `
        -SqlInstance $instanceName `
        -Database $db `
        -OutputPath (Join-Path -Path $outputDir -ChildPath "$db-schema.json")
    
    Write-Host "✓ $db completed" -ForegroundColor Green
}

Write-Host "`nAll databases processed in: $baseOutput" -ForegroundColor Cyan


<#
================================================================================
    EXAMPLE 8: SQL Authentication
    
    Scenario: Connect using SQL Server login instead of Windows auth
================================================================================
#>

Write-Host "`nExample 8: SQL Server Authentication" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan

# Create credential object
$sqlCred = New-Object System.Management.Automation.PSCredential (
    "sa",
    (ConvertTo-SecureString "YourPassword123!" -AsPlainText -Force)
)

# Use credential for all operations
$schema = Get-DatabaseSchema `
    -SqlInstance "SQLSERVER01" `
    -Database "Demo" `
    -Credential $sqlCred

Write-Host "Connected using SQL authentication" -ForegroundColor Green


<#
================================================================================
    EXAMPLE 9: Customize Generated Seeding Script
    
    Scenario: After generation, customize data patterns
================================================================================
#>

Write-Host "`nExample 9: Customize Seeding Script" -ForegroundColor Cyan
Write-Host "===================================" -ForegroundColor Cyan

# Generated script path
$seedScript = "C:\Scripts\Seed-Customer.sql"

# Read generated script
$content = Get-Content -Path $seedScript -Raw

# Example customization: Replace TODO with actual data logic
$customized = $content -replace "/* TODO: Add values for each column \*/", @"
CustomerID,              -- auto-identity
'CUST-' + CAST(@counter AS varchar(10)),  -- CustomerCode
'Customer Name ' + CAST(@counter AS varchar(10)),  -- Name
DATEADD(DAY, -RAND() * 365, CAST(GETDATE() AS date)), -- RegisterDate
CONVERT(numeric(10, 2), RAND() * 100000) -- CreditLimit
"@

# Save customized script
$customized | Set-Content -Path "C:\Scripts\Seed-Customer-Custom.sql"

Write-Host "Customized seeding script: C:\Scripts\Seed-Customer-Custom.sql" -ForegroundColor Green


<#
================================================================================
    EXAMPLE 10: Generate Reports and Summaries
    
    Scenario: Create comprehensive documentation from schema
================================================================================
#>

Write-Host "`nExample 10: Generate Documentation Reports" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# Load schema
$schema = Get-Content "C:\Schemas\Demo-schema.json" | ConvertFrom-Json

# Create summary report
$report = @"
================================================================================
                    DATABASE SCHEMA DOCUMENTATION
                              Demo Database
================================================================================

Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

TABLE SUMMARY
=============

"@

foreach ($table in $schema)
{
    $columnCount = ($table.columns | Measure-Object).Count
    $report += "`n[$($table.table_schema)].[$($table.table_name)]`n"
    $report += "  Columns: $columnCount`n"
    $report += "  Details:`n"
    
    foreach ($column in $table.columns)
    {
        $nullable = if ($column.is_nullable) { "NULL" } else { "NOT NULL" }
        $identity = if ($column.is_identity) { " IDENTITY" } else { "" }
        $pk = if ($column.is_primary_key) { " PRIMARY KEY" } else { "" }
        
        $report += "    - $($column.column_name) [$($column.data_type)]$nullable$identity$pk`n"
    }
}

$reportPath = "C:\Reports\Schema-Documentation.txt"
$report | Out-File -FilePath $reportPath -Encoding UTF8

Write-Host "Documentation report created: $reportPath" -ForegroundColor Green
Write-Host $report


<#
================================================================================
    EXAMPLE 11: Execute Generated Utility Script
    
    Scenario: Create index maintenance job in database
================================================================================
#>

Write-Host "`nExample 11: Deploy DBA Utility Script" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan

# Read generated utility script
$utilityScript = Get-Content -Path "C:\Scripts\IndexMaintenance-Utilities.sql" -Raw

# Execute against target database
Invoke-DbaQuery `
    -SqlInstance "SQLSERVER01" `
    -Database "Demo" `
    -Query $utilityScript

Write-Host "Index maintenance procedure deployed successfully" -ForegroundColor Green

# Call the procedure to test
Invoke-DbaQuery `
    -SqlInstance "SQLSERVER01" `
    -Database "Demo" `
    -Query "EXECUTE dbo.usp_maintain_indexes @debug = 1" | Format-Table


<#
================================================================================
    EXAMPLE 12: Validate Schema Extraction
    
    Scenario: Compare extracted schema with actual database
================================================================================
#>

Write-Host "`nExample 12: Validate Schema Extraction" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan

# Get extracted schema
$extracted = Get-DatabaseSchema `
    -SqlInstance "SQLSERVER01" `
    -Database "Demo" `
    -OutputFormat TABLE

# Count tables
$tableCount = ($extracted | Select-Object -Unique table_name | Measure-Object).Count
Write-Host "Tables extracted: $tableCount" -ForegroundColor Green

# Count total columns
$columnCount = ($extracted | Measure-Object).Count
Write-Host "Columns extracted: $columnCount" -ForegroundColor Green

# Show sample
Write-Host "`nSample extracted metadata:" -ForegroundColor Yellow
$extracted | Select-Object table_schema, table_name, column_name, data_type -First 10 | Format-Table


<#
================================================================================
    EXAMPLE 13: Partial Workflow - Seeding Only
    
    Scenario: Already have schema, just generate seeding scripts
================================================================================
#>

Write-Host "`nExample 13: Seeding-Only Workflow" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

# Run with ExportType filter
& ".\scripts\powershell\Generate-DemoScripts.ps1" `
    -SqlInstance "SQLSERVER01" `
    -Database "Demo" `
    -OutputPath "C:\DemoScripts" `
    -ExportType "Seeding" `
    -SeedRowCount 250


<#
================================================================================
    QUICK REFERENCE: Common Tasks
================================================================================
#>

Write-Host "`n" -ForegroundColor Cyan
Write-Host "QUICK REFERENCE: Common Tasks" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan

$quickRef = @"

1. Extract full schema:
   Get-DatabaseSchema -SqlInstance "SERVER" -Database "DB" | ConvertTo-Json | Out-File schema.json

2. Export to file:
   Export-SchemaMetadata -SqlInstance "SERVER" -Database "DB" -OutputPath "C:\schema.json"

3. Get indexes:
   Get-IndexMetadata -SqlInstance "SERVER" -Database "DB" | Export-Csv indexes.csv

4. Generate seeding:
   New-DataSeedingScript -SchemaObject `$schema -TableName "Table" -RowCount 100 -OutputPath "Seed.sql"

5. Generate utility:
   New-DBAUtilityScript -Database "DB" -UtilityType "IndexMaintenance" -OutputPath "Maintain.sql"

6. Run complete workflow:
   .\Generate-DemoScripts.ps1 -SqlInstance "SERVER" -Database "DB" -OutputPath "C:\Out" -ExportType "All"

7. Multi-database batch:
   @("DB1","DB2","DB3") | ForEach-Object { Export-SchemaMetadata ... }

8. Filter by schema:
   Get-DatabaseSchema -SqlInstance "SERVER" -Database "DB" -SchemaName "Sales"

9. With SQL credentials:
   `$cred = Get-Credential; Get-DatabaseSchema ... -Credential `$cred

10. Data distribution:
    Get-DataDistribution -SqlInstance "SERVER" -Database "DB" -SchemaName "dbo" -TableName "Table"

"@

Write-Host $quickRef
Write-Host ""
