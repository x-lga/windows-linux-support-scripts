**What ticket this solves:** "Website won't load" or "I can't reach [internal resource]
by name" - often caused by a stale or corrupt DNS cache entry pointing to an old IP
address. A DNS flush clears the local resolver cache and forces the machine to query
the DNS server fresh on the next lookup.

**Why this is more than just `ipconfig /flushdns`:** This script checks whether
the flush succeeded by verifying the cache is empty afterwards, catches the case
where the DNS Client service is not running (which prevents flushing), provides
clear output with a confirmation test, and is safe to run on any machine without
elevated privileges for the flush operation itself.

**Cert alignment:** CompTIA A+, CompTIA Network+
