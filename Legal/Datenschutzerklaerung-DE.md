# Datenschutzerklärung für ATS Diagnostic

Stand: 12. Oktober 2026

## Verantwortlicher und Kontakt

MOBILE BOX – App Consulting UG (haftungsbeschränkt)  
Augustenburgstrasse 88, 76229 Karlsruhe, Deutschland  
E-Mail: info@mobilebox-consulting.de  
Telefon: +49 (0) 151 52458996

Diese Erklärung beschreibt die native iPhone-/iPad-App ATS Diagnostic. Für den Besuch unserer Website gelten ergänzend deren Datenschutzhinweise. Die Angaben beziehen sich auf die hier beschriebene App-Version und ihre tatsächlichen Funktionen.

## Keine zentrale Sammlung von Diagnosedaten

ATS Diagnostic benötigt kein Benutzerkonto. Wir betreiben für die App keinen Dienst, an den Diagnosehistorie, Anfrageinhalte oder Zertifikate automatisch übertragen werden. Die App enthält keine eingebundenen Werbe-, Tracking- oder Analyse-SDKs. Wir verwenden die App-Diagnosen nicht für Werbung oder zur Erstellung von Nutzerprofilen.

„Keine Daten erfasst“ in den App-Store-Datenschutzangaben bedeutet nicht, dass keine Netzwerkverbindungen stattfinden. Die App sendet die von Ihnen ausgelösten Anfragen an die gewählten Ziele und verarbeitet deren Antworten.

## Von Ihnen ausgewählte Server und Netzwerkdienste

Bei einer Prüfung verbindet sich die App mit der von Ihnen eingegebenen Adresse. Der Zielserver und beteiligte Netzwerkdienste können insbesondere Ihre öffentliche IP-Adresse, den angefragten Hostnamen, Zeitpunkt und technische Verbindungsdaten erhalten. HTTP-Anfragen können die eingegebene URL einschließlich Pfad und Parametern sowie Header und Anfragekörper enthalten. Weiterleitungen können zu weiteren Servern führen.

Falls Sie Zugangsdaten, Tokens oder personenbezogene Angaben in eine Anfrage aufnehmen, werden diese entsprechend der Anfrage an den Zielserver übermittelt. Verwenden Sie solche Angaben nur für Ziele, denen Sie vertrauen. Die DNS-Auflösung erfolgt über die vom Gerät beziehungsweise Netzwerk verwendeten Dienste; diese können die abgefragten Hostnamen erhalten. Für die Datenverarbeitung fremder Server und DNS-Anbieter sind deren Betreiber verantwortlich.

Die App erlaubt zur Diagnose fremder Konfigurationen auch unverschlüsseltes HTTP und ältere TLS-Konfigurationen. Unverschlüsselte Verbindungen können von Dritten im Übertragungsweg mitgelesen oder verändert werden. Die normale HTTPS-Zertifikatsprüfung bleibt aktiv. Eine erfolgreiche Diagnose ist keine Garantie für die Sicherheit oder ATS-Konformität eines Servers.

Bei Zertifikats- und Sperrprüfungen kann die System-Vertrauensprüfung zusätzliche Ausstellerinformationen, OCSP-Antworten oder Zertifikatssperrlisten abrufen. Eine ausdrücklich gestartete Sperrprüfung kann Verbindungen zu den im Zertifikat beziehungsweise durch dessen Aussteller angegebenen Diensten auslösen. Dabei können die Anbieter Ihre IP-Adresse und technische Zertifikatskennungen erhalten. Die App zeigt vorhandene Certificate-Transparency-Nachweise und mitgelieferte Logverzeichnisse an; daraus folgt keine automatische Übertragung Ihrer gesamten Diagnosehistorie an CT-Logs.

## Verarbeitung und Speicherung auf Ihrem Gerät

Die App verarbeitet eingegebene Adressen und Anfragen, Antwortstatus und Header, begrenzte Körpervorschauen, Zertifikate, Fingerprints, Zeitmessungen, Verbindungsmetadaten und ursprüngliche Fehler. HTTP-Header und Körper können Cookies, Tokens oder andere vertrauliche beziehungsweise personenbezogene Daten enthalten.

Abgeschlossene Diagnosen werden lokal im App-Speicher aufbewahrt, bis Sie Einträge oder die Historie löschen oder die Speichergrenzen der App ältere Einträge entfernen. Die Historie hat eine begrenzte Anzahl von Einträgen und ein begrenztes Speicherbudget; Körpervorschauen sind ebenfalls begrenzt. Einstellungen bleiben lokal gespeichert. Die App verwendet die Schutzmechanismen von iOS; dies ersetzt nicht die Absicherung Ihres Geräts.

Geräte- oder iCloud-Sicherungen können je nach Ihren Apple-Einstellungen App-Daten enthalten. Solche Sicherungen werden durch das Betriebssystem beziehungsweise Apple verwaltet, nicht durch einen eigenen ATS-Diagnostic-Server. Das Entfernen lokaler Einträge löscht nicht automatisch Kopien in bereits erstellten Sicherungen oder Exporten.

## Lokales Netzwerk und Proxy

Der Zugriff auf das lokale Netzwerk dient der Prüfung von Geräten und Servern, die Sie auswählen. Die Systemberechtigung können Sie in den iOS-Einstellungen erteilen oder widerrufen. Ohne diese Berechtigung können lokale Prüfungen eingeschränkt sein. Internetprüfungen benötigen diese lokale Berechtigung grundsätzlich nicht.

Der optionale HTTP-Proxy wird von Ihnen gestartet, ist auf die lokale Loopback-Schnittstelle dieses Geräts beschränkt und wird beim Wechsel in den Hintergrund gestoppt. Er kann die durch ihn geleiteten HTTP-Anfragen und begrenzte Vorschauen aufzeichnen. HTTPS-CONNECT-Verbindungen werden als undurchsichtiger Tunnel weitergeleitet; die App entschlüsselt dabei keine HTTPS-Inhalte und installiert keine eigene Root-CA. Es handelt sich nicht um einen geräteweiten VPN-Dienst.

## Exporte, Freigaben und externe Links

Berichte, HAR-Dateien, Zertifikate und weitere Exporte werden nur durch Ihre Bedienung erstellt beziehungsweise geteilt. Prüfen Sie den Inhalt vor einer Freigabe. Empfänger, gewählte Apps oder Cloud-Dienste können die exportierten Daten anschließend nach ihren eigenen Regeln verarbeiten und speichern. Wir können bereits weitergegebene Kopien nicht zurückholen oder löschen.

Wenn Sie einen externen Link öffnen, erhält der jeweilige Websitebetreiber die für den Aufruf erforderlichen Daten. Dann gelten zusätzlich dessen Datenschutzhinweise.

## Benachrichtigungen und Apple-Dienste

Auf Ihren Wunsch kann die App lokale Erinnerungen an das Ablaufen von Zertifikaten planen. Dafür fragt sie die Mitteilungsberechtigung ab. Erinnerungsinformationen können auf dem Sperrbildschirm erscheinen, abhängig von Ihren Einstellungen. Sie können die Berechtigung in iOS widerrufen und geplante Erinnerungen in der App verwalten.

Downloads, Käufe, Geräte-Sicherungen und gegebenenfalls von Ihnen freigegebene Systemdiagnosen werden durch Apple nach Apples Datenschutzbestimmungen verarbeitet. Wir integrieren keinen eigenen automatischen Crash-Upload. Freiwillig über TestFlight oder direkt an uns gesendetes Feedback kann Screenshots, technische Angaben und Kontaktdaten enthalten.

## Support, Rechtsgrundlagen und Ihre Rechte

Wenn Sie uns kontaktieren oder Feedback übermitteln, verarbeiten wir die von Ihnen übermittelten Informationen zur Bearbeitung Ihrer Anfrage. Senden Sie nur erforderliche Daten und entfernen Sie vertrauliche Anfrageinhalte. Rechtsgrundlagen sind, soweit anwendbar, Art. 6 Abs. 1 lit. b DSGVO zur Bearbeitung vertragsbezogener Anfragen sowie Art. 6 Abs. 1 lit. f DSGVO für unser berechtigtes Interesse an Support und Fehlerbehebung. Gesetzliche Aufbewahrungspflichten beruhen auf Art. 6 Abs. 1 lit. c DSGVO. Freiwillige Einwilligungen können Sie für die Zukunft widerrufen. Supportdaten bewahren wir nur so lange auf, wie die Bearbeitung und gegebenenfalls gesetzliche Pflichten dies erfordern.

Soweit die gesetzlichen Voraussetzungen vorliegen, haben Sie Rechte auf Auskunft, Berichtigung, Löschung, Einschränkung der Verarbeitung, Datenübertragbarkeit und Widerspruch. Sie können sich an info@mobilebox-consulting.de wenden und bei einer Datenschutzaufsichtsbehörde beschweren, insbesondere am Ort Ihres gewöhnlichen Aufenthalts oder unseres Unternehmenssitzes. Lokal ausschließlich auf Ihrem Gerät vorhandene Diagnosedaten stehen uns nicht für eine Auskunft oder Löschung zur Verfügung; diese verwalten Sie in der App und in Ihren Geräte-/Sicherungseinstellungen.

## Änderungen

Bei Änderungen der Funktionen oder Datenverarbeitung aktualisieren wir diese Erklärung. Die jeweils veröffentlichte Fassung finden Sie unter:

https://www.mobilebox-consulting.de/datenschutzerklärung-privacy-policy/
