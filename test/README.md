# Tests

- `plc/` enthält TcUnit-Tests für die SPS-Logik (Meldeliste, Sicherheitsüberwachung, Zustandsmaschine,
  Spindel). **Stand: geschrieben, noch nicht ausgeführt.** Sie laufen erst, wenn ein TwinCAT-Projekt mit TcUnit
  auf der Usermode Runtime am Laptop vorliegt.
- `gcode/` (folgt): Fusion-Testprogramme des Kunden und die erwarteten Ergebnisse für die simulierte CNC.
- Syntaxprüfung der `.st`-Dateien vorab mit `blark parse <datei>` (Python-Paket `blark`).
