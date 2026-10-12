# Duplex-Testclient

TCPExchange im kontrollierten Loopback-Test beginnt jetzt sofort nach Connection-ready zu lesen, während der Upload gesendet wird. Vorher wartete es mit Lesen bis zum vollständigen Send-Abschluss. Bei einem echoenden Peer und begrenzten Netzwerkpuffern kann das gegenseitigen Rückstau verursachen. Die Änderung betrifft ausschließlich den Testclient; Produktions-Proxy und Größen-/Half-Close-Assertions sind unverändert.

Alle neun LocalProxyTests bestehen im gezielten iPad-Lauf, einschließlich 512-KiB-CONNECT-Echo und beider Half-Close-Richtungen. Danach besteht die gesamte App-Suite mit 108 Testmethoden, ohne Fehler oder Laufzeitwarnungen. Die vorherigen Network-is-down-Fehler bleiben dokumentiert. Das fehlerhafte Test-I/O-Muster ist korrigiert; ein ausschließlicher kausaler Nachweis für diese konkrete Fehlermeldung liegt nicht vor.
