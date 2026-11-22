# SQL Queries & Automation Workspace

A comprehensive VS Code workspace for SQL Server administration, PowerShell automation, Windows Server management, and IT recruitment coordination.

## ⚠️ CRITICAL: Always Use Agent Syntax

**EVERY request must specify which agent to use using `@` syntax:**

```
@SQL Server Admin [your request]
@PowerShell Dev [your request]
@Windows Server Admin [your request]
@Communications Recruiter [your request]
```

**Without specifying an agent, you won't get workspace-optimized responses with proper standards and best practices.**

---

## Overview

This workspace brings together specialized agent configurations, coding standards, and script organization to support multiple roles:

- **SQL Server Administration**: Performance tuning, T-SQL development, HA/DR solutions
- **PowerShell Development**: Automation scripting, infrastructure management
- **Windows Server Administration**: Server deployment, security, Active Directory
- **IT Recruitment**: Talent acquisition, hiring strategies, team building

## Quick Start

### Using Agents

When you need help with a specific task, invoke the appropriate agent:

```
@SQL Server Admin - Write a query to analyze missing indexes
@PowerShell Dev - Create an automation script for backups
@Windows Server Admin - Set up Active Directory password policy
@Communications Recruiter - Create a job posting for a DBA role
```

### Creating Scripts

All generated scripts go to the `/scripts/` folder:

- `/scripts/sql/` — T-SQL queries and stored procedures
- `/scripts/powershell/` — PowerShell automation scripts
- `/scripts/deployment/` — Deployment and infrastructure scripts
- `/scripts/recruitment/` — Recruitment templates and documents

## Keeping Your Workspace Updated

When you open this workspace, Copilot will check if there are newer versions of agent or instruction files available in the template workspace. If updates are found, you'll be prompted:

```
✨ Workspace updates available!
Newer versions found for:
  • SQL-Server-admin.instructions.md
  • powershell-dev.agent.md
  
Would you like to update these files to the latest versions? (Yes/No)
```

**To update your workspace:**

1. Choose **Yes** when prompted, or manually follow the [MAINTENANCE.md](MAINTENANCE.md) guide
2. Files will be updated from the template workspace with latest best practices
3. Your custom scripts in `/scripts/` folder are never affected

**Why update?**
- Get the latest agent capabilities and improvements
- Adopt updated coding standards and best practices
- Fix any issues resolved in newer versions
- Stay consistent with template workspace standards
