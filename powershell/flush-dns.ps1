**What ticket this solves:** "Website won't load" or "I can't reach [internal resource]
by name" - often caused by a stale or corrupt DNS cache entry pointing to an old IP
address. A DNS flush clears the local resolver cache and forces the machine to query
the DNS server fresh on the next lookup.
