# Deployment Scripts

Store your deployment and infrastructure automation scripts here.

## Naming Convention

- Use descriptive Verb-Noun format: `Deploy-Application.ps1`, `Configure-ServerHA.ps1`
- Include environment context if needed: `Deploy-Production-FailoverCluster.ps1`

## File Organization

```
deployment/
├── Configure-ServerHA.ps1
├── Deploy-FailoverCluster.ps1
├── Apply-SecurityBaseline.ps1
└── [your-scripts-here]
```

## Best Practices

- All deployment scripts must be production-ready with comprehensive validation
- Include pre-flight checks and system requirements validation
- Implement robust error handling and rollback procedures
- Add detailed logging to track deployment progress
- Document parameters and usage examples
- Include dry-run or simulation mode when appropriate
- Test thoroughly in lab environments before production use
- Provide clear success/failure indicators
- Include pre-deployment and post-deployment checklists
- Document dependencies and prerequisites

## Windows Server Administration

When creating server deployment and configuration scripts:
- Follow best practices from [Windows Server Admin instructions](../instructions/windows-server-admin.instructions.md)
- Reference Microsoft Security Baselines and CIS Benchmarks
- Include both manual steps and PowerShell automation
- Validate all changes in test environments first
- Provide monitoring and validation steps after deployment
