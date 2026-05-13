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

## Principle 3: Validate Inputs Before Acting

Every script validates its inputs before touching the system:
- Does the directory exist before trying to read it?
- Does the service name exist before trying to stop it?
- Is the username already taken before trying to create it?
- Is the confirmation exactly what we expect before an irreversible action?

Validating first means the script fails before making any changes, not halfway
through. A half-executed offboarding or a half-cleared spool directory is worse
than no action at all.

---

## Principle 4: Confirmation for Destructive Actions

Scripts that perform irreversible actions require explicit confirmation before
executing. `Reset-NetworkStack.ps1` requires the user to type `RESET`. This is
not excessive caution - it prevents the script from being run accidentally, and
it forces the technician to consciously decide this is the right action.

The confirmation string is chosen to be long enough that it cannot be accidentally
typed (`RESET`, `OFFBOARD`) rather than a single keypress (`Y`) that could be
entered by mistake.

---

## Principle 5: Log What Happened

Scripts that modify system state produce an audit trail. Every `Restart-ServiceWithCheck.ps1`
execution is logged. Every `user-provision.sh` execution is logged. Every
`backup-with-timestamp.sh` execution is logged. The log includes:
- Timestamp
- What action was taken
- What the result was
- Who ran it (where this can be determined)

This matters for both troubleshooting ("why did service X restart at 3am?") and
compliance ("who created this user account and when?").

---

## Principle 6: Show the State Before and After

Where appropriate, scripts show the state before they act and confirm the state
after. `Clear-PrintQueue.ps1` counts jobs before clearing and confirms the spooler
is running after restarting. `Get-DiskSpace.ps1` shows current free space.
`Restart-ServiceWithCheck.ps1` shows the service status before stopping and
confirms it is running after starting.

This gives the technician confidence that the action actually worked and something
useful to include in the ticket notes.

---

