# **What ticket this solves:** Linux servers accumulate log files in `/var/log` and
# application-specific log directories. Without maintenance, these grow to fill the
# disk and cause service failures. This script automates the cleanup — moving old
# logs to an archive directory, compressing them, and deleting archives older than
# the configured retention period.

# **Cert alignment:** CompTIA A+
