<# **What ticket this solves:** "I can't print - there's a job stuck in the queue" is
one of the most frequent L1 help desk calls. A stuck print job blocks all subsequent
jobs in the queue. Clearing it manually requires opening Services, stopping the
Print Spooler, navigating to the spool folder, deleting files, and restarting
the service - a 3-minute process with multiple steps that technicians often get
wrong (forgetting to stop the service before deleting files, or not restarting it). 

**Why this script matters:** It handles the complete workflow - stops the spooler,
deletes stuck jobs, restarts the spooler, and confirms the service came back up
cleanly. It also handles the case where the spooler service cannot be stopped
(rare but real) without crashing.

#>
