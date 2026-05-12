# Script Design Principles

This document explains the design decisions behind every script in this repository.
Understanding these principles is valuable for both using the scripts correctly and
for understanding what makes a production-quality script different from a quick
one-liner.

---

## Principle 1: Every Script Has a Single Clear Purpose

Each script does one thing and communicates clearly what that one thing is.
`Clear-PrintQueue.ps1` clears the print queue - it does not also update drivers
or check network connectivity. Single-purpose scripts are:
- Easier to understand at a glance
- Easier to troubleshoot when something goes wrong
- Safer to run because their impact is predictable
- Easier to combine with other scripts in a larger workflow

---

## Principle 2: Fail Loudly with a Clear Error Message

When a script encounters a problem, it stops immediately and tells the technician
exactly what went wrong in plain language. It does not:
- Continue silently and produce incorrect results
- Fail with a cryptic PowerShell or bash error without context
- Exit without telling the technician what to do next

Every `try/catch` block in PowerShell and every exit code check in Bash produces
a human-readable message that diagnoses the problem and suggests the next action.

---

