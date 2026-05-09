<# **What ticket this solves:** "Application X is not responding" — many application
issues are resolved by restarting the underlying Windows service. Doing this
manually means opening Services.msc, finding the service, right-clicking,
stopping, waiting, and starting. This script does it in one command with timeout
handling, status verification, and clear output showing what happened.


#>