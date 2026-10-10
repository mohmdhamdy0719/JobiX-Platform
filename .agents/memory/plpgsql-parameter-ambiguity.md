---
name: PL/pgSQL parameter qualification
description: Avoid runtime ambiguity when function parameters share names with database columns.
---

**Rule:** In PL/pgSQL functions whose argument names overlap table columns, qualify both argument and column references in SQL statements. Use `ON CONFLICT ON CONSTRAINT` when conflict-column names overlap function arguments.

**Why:** Cost-admission integration tests exposed ambiguities in conflict targets and reservation lookups that compiled successfully but failed only at runtime.

**How to apply:** Review new and replaced database functions for argument/column name overlap, including `INSERT`, `UPDATE`, `SELECT`, and `ON CONFLICT` clauses; cover each path with a disposable-database test.

In PL/pgSQL, qualify table columns with aliases when a local variable shares the name; function-name qualification is for input arguments, not `DECLARE` locals.

**Why:** Runtime queries in cost-purge tests exposed local-variable/column ambiguity and an invalid function-qualified local reference after the function body compiled.

**How to apply:** Give local variables distinct names where practical, and qualify columns in embedded SQL statements; exercise the statements in PostgreSQL rather than relying on function creation success.
