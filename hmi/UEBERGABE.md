# Übergabe HMI-Konzept (Stand 05.11.2026, 21:30)

Von: Konzept-Thread "HMI Bedienoberfläche konzipieren". An: Laptop-Thread "Bauen: TwinCAT-HMI auf dem Laptop".

## Was fertig ist
- 10 Bilder als Wireframes (`wireframes/P-016_HMI-Konzept_M1_ENTWURF.html`, auch als Artifact https://claude.ai/artifact/D4HoehBH2AL1ANfbY1y9K2): Übersicht, Hand, Referenz, Automatik, Programme, Werkzeuge, Nullpunkte, Meldungen, Diagnose, Service. Aufbau jedes Bildes: Kopfzeile, Meldezeile, Arbeitsbereich, Funktionsleiste mit STOPP (Kapitel 4 der Softwaredokumentationsvorlage).
- `spec/Bildschirmtabelle_SPS-HMI.md` und `spec/screens.json`: je Bild die Variablen mit Typ, Richtung, Quelle und Status. `spec/alarm-texts.de.json`: Klartext und Abhilfe zu den Alarm-IDs 100 bis 900.
- `design/tokens.css`: NIKLAS-Petrol #255975 (nicht das Türkis aus dem CARE-Angebot), Schrift Helvetica/Arial, Mindestgröße Schaltfläche 44 px. Ziel 1920x1080 Querformat, Wireframes sind auf 960x540 gezeichnet (Faktor 2).

## Schnittstellenstand
- `GVL_HMI.stCmd : ST_HmiCmd`, `stSts : ST_HmiSts` (Typen im SPS-Branch `claude/project-thread-hr9kgm`, `twincat/PLC/src/6_Interfaces/`). Alle Wünsche der HMI sind dort eingetragen, bis auf `aDI/aDO` (Diagnosebild zeigt vorerst nur Statussignale) und getrennte EtherCAT/CANopen-Zustände.
- CNC-Spiegel: `GVL_HmiCnc.stCncSts : ST_HmiCncSts`, `stCncCmd : ST_HmiCncCmd` (zugesagt vom CPU-Thread, Datei `ST_HmiCnc.st`, beim letzten Prüfen noch nicht im Branch). Nur TF2000 installiert, also keine CNC-HMI-Controls. Programm laden und Tabellen schreiben nur im Stillstand, sonst `bTableWriteRejected`.
- Achsnummern der HMI: 1 = X, 2 = Y (Gantry), 3 = Z, gilt für `nJogAxis`, `bHomeAxis[1..3]`, `nHandwheelAxis`, `aAxis[1..3]`. `aDrive[1..4]` = Y1, Y2, X, Z [Annahme].
- HMI fordert nur an, Verriegelungen liegen in der SPS. `nHeartbeat` zählt die HMI hoch (Ausfall stoppt Tippen). STOPP ist ein Software-Stopp und kein Not-Halt.

## Annahmen und offene Punkte
- Achsbenennung X (Quer), Y (Portal), Z und Referenzreihenfolge Z, Y, X sind Annahmen. Verfahrwege, Referenz- und Endschalter-Lage fehlen (Schaltplan).
- Rollen Bediener, Einrichter, Service sind Annahme (Priorität Kann, keine Kundenaussage). Nur Deutsch.
- Handrad (Bestandsgerät M1), Stückzähler, Restzeit, Werkzeuglänge messen: offen, nicht in der Grundversion.
- Programmliste (Dateiverzeichnis) liest die HMI ohne SPS aus dem Freigabeordner, Pfad und Namenskonvention der Fusion-Dateien offen.
- Sonderanforderungen (Vorschau/Simulation, Wiederaufnahme ab Satz, Englisch, Fernzugriff-Freigabe) sind für später.
- Noch nichts im TwinCAT-HMI-Projekt P016_HMI angelegt und nichts gegen die Simulation getestet.

## Nächste Schritte
1. Bilder mit TF2000-Standard-Controls bauen, Symbole an `GVL_HMI` und `GVL_HmiCnc` binden, Wireframe-Layout (Funktionsleiste unten, STOPP rechts) übernehmen.
2. Meldetexte aus `alarm-texts.de.json` einbinden, Meldezeile aus `aAlarms[]`/`nTopAlarmId`.
3. Gegen die Usermode Runtime mit simulierten Achsen testen, danach unabhängige Prüfung.
