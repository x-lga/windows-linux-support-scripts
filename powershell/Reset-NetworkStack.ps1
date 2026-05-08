<# **What ticket this solves:** Network connectivity failures that persist after all
standard L1 steps (DNS flush, ipconfig /release /renew, cable check) have been
attempted. A corrupt Winsock catalog or TCP/IP stack requires a stack reset to
restore normal network function. This is a last resort before escalating.

**Why this script has a confirmation step:** The reset requires a restart to take
effect, and the commands are irreversible without a restart. Running this on a
server that cannot be restarted immediately would be harmful. The script requires
explicit confirmation before executing and warns clearly that a restart is required.


#>