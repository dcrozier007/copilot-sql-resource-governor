# SQL Scripts

Store your T-SQL scripts and stored procedures here.

## Naming Convention

- Use descriptive snake_case names: `missing_indexes.sql`, `analyze_blocking_chains.sql`
- Include the purpose in the filename when possible

## File Organization

```
sql/
├── analyze_blocking_chains.sql
├── missing_indexes.sql
├── backup_verification.sql
└── [your-scripts-here]
```

## Best Practices

- All SQL code must follow [T-SQL-Coding-Style-Guide.md](../instructions/T-SQL-Coding-Style-Guide.md)
- Start with `USE [database_name];` to specify target database
- Include comments describing purpose and usage
- Test scripts in a dev/test environment first
- For stored procedures, use `CREATE OR ALTER PROCEDURE` syntax
- Always include proper error handling and validation
