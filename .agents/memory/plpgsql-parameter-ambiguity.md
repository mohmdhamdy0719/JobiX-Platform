---
name: PL/pgSQL parameter qualification
description: Avoid runtime ambiguity when function parameters share names with database columns.
---

**Rule:** In PL/pgSQL functions whose argument names overlap table columns, qualify both argument and column references in SQL statements. Use `ON CONFLICT ON CONSTRAINT` when conflict-column names overlap function arguments.

**Why:** Cost-admission integration tests exposed ambiguities in conflict targets and reservation lookups that compiled successfully but failed only at runtime.

**How to apply:** Review new and replaced database functions for argument/column name overlap, including `INSERT`, `UPDATE`, `SELECT`, and `ON CONFLICT` clauses; cover each path with a disposable-database test.
