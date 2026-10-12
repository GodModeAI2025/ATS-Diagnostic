# System reverse address lookup

The DNS utility now supports explicit reverse lookup of numeric IPv4/IPv6 addresses, including scoped IPv6 literals. Input validation rejects hostnames, URLs and IPv4 port suffixes before resolution. Blocking native getnameinfo with NI_NAMEREQD runs off the UI thread; getaddrinfo uses AI_NUMERICHOST and allocated memory is freed. A missing name remains an error rather than silently displaying the original numeric address as a hostname.

The native result identifies the system resolver as its source and explains that local name sources may contribute. It does not claim DNSSEC, a raw PTR query, server identity or certificate trust. Forward lookup remains available.

Three targeted test methods passed (including six parameterized invalid inputs), followed by the complete app suite. See Tests.json and FullTests.json. Native iPhone simulator UI verification passed: 8.8.8.8 → dns.google; ::1 → localhost; example.com rejected for reverse lookup with an understandable input message; forward example.com returned four addresses. No UI defects observed; session closed. Screenshots and accessibility captures are saved under Release/Screenshots/Reverse-DNS-*. This source is not in TestFlight51 or submitted Store50.
