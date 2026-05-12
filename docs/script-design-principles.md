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
