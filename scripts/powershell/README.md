# PowerShell Scripts

Store your PowerShell automation scripts here.

## Naming Convention

- Use descriptive Verb-Noun format: `Backup-AllDatabases.ps1`, `Get-BlockingChains.ps1`
- For dbatools-based scripts, include "dbatools" in the name if relevant: `Backup-DbaMultiServer.ps1`

## File Organization

```
powershell/
├── Backup-AllDatabases.ps1
├── Get-HealthStatus.ps1
├── Invoke-InstanceConfiguration.ps1
└── [your-scripts-here]
```

## Best Practices

- Use PowerShell naming conventions: `Verb-Noun` format for functions and scripts
- Include help documentation (`#` comment-based help)
- Implement error handling with Try-Catch-Finally blocks
- Add parameter validation and type hints
- Include logging for production scripts
- Document dependencies (modules, required versions)
- For SQL Server automation, use dbatools functions when available
- Always include usage examples in comments

## dbatools Integration

When using dbatools functions, always:
- Reference the official documentation at [dbatools.io](https://dbatools.io/)
- Include comprehensive error handling
- Test multi-server scenarios
- Document connection and credential requirements
