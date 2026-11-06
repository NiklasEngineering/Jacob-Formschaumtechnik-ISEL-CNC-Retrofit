# Anforderungsmatrix Grundfunktionen (Muss)

Stand: 05.11.2026. Grundlage: Klärungsliste Funktionen vom 28.10.2026 (Priorität Muss/Soll), **nicht** das mit dem
Kunden abgestimmte Lastenheft ("Kopie 2"), das noch nicht im Projektordner liegt. Sobald es vorliegt, wird die Matrix
abgeglichen. IDs = Nummern der Klärungsliste mit Präfix `LH-`.

Status: **Logik** = SPS-Logik vorhanden (nicht erprobt), **CNC** = wird in der CNC parametriert (kein SPS-Code),
**HMI** = Sache des HMI-Threads, **offen** = nicht umgesetzt oder braucht Hardwaredaten.

| ID | Anforderung | Umsetzung | Baustein / Ort | Status | Testfall |
|---|---|---|---|---|---|
| LH-2.1.1 | Betriebsarten Hand, Automatik, Einrichten/Test | FB_OpModeManager | 4_Machine | Logik | T-MODE-01 |
| LH-2.1.2/3 | Einheitliche Oberfläche, Touch | HMI | HMI-Thread | HMI | – |
| LH-2.1.4 | Statuszeile und Meldefenster in Klartext | Meldekatalog, Texte in HMI | 5_Messages, HMI | Logik/HMI | T-ALM-01 |
| LH-2.2.1 | Referenzfahrt, Reihenfolge einstellbar | FB_Homing, Referenzieren in CNC | 4_Machine, cnc/ | Logik, CNC offen | T-HOME-01 |
| LH-2.2.2 | Werkstücknullpunkte G54 bis G59 | CNC-Nullpunkttabelle | cnc/, TF5310 | CNC | – |
| LH-2.2.3 | Hardware-Endschalter überwachen | FB_AxisSupervisor | 2_Devices | Logik, Verdrahtung offen | T-AXS-01 |
| LH-2.2.4 | Software-Endschalter je Achse | CNC-Achsparameter | cnc/ | CNC offen | – |
| LH-2.2.5 | Absolut/inkremental (G90/G91), mm | CNC | – | CNC | – |
| LH-2.2.6 | Verhalten bei Referenzverlust | FB_AxisSupervisor, Meldung 320 (R4) | 2_Devices, 5_Messages | Logik | T-AXS-02 |
| LH-2.3.1 | Achsen tippen mit Schrittweiten | FB_Jog, Schrittweite an CNC | 4_Machine | Logik | T-JOG-01 |
| LH-2.3.2 | Eilgang und Vorschub im Handbetrieb | FB_Jog (bRapid), Override über CNC | 4_Machine | Logik | T-JOG-02 |
| LH-2.4.1 | Programm wählen, laden, starten, anhalten, fortsetzen | FB_MachineState, Auswahl über TF5310 | 4_Machine | Logik/HMI | T-STATE-01 |
| LH-2.4.2 | Programm abbrechen mit definiertem Zustand | FB_MachineState (Aborted, Spindel aus) | 4_Machine | Logik | T-STATE-02 |
| LH-2.4.3 | Vorschub-Override | CNC-Override über HMI | TF5310 | CNC/HMI | – |
| LH-2.4.4 | M0/M1, M2/M30 | FB_MFunctions, bOptStop | 3_Cnc | Logik | T-MFN-01 |
| LH-2.5.1 bis 2.5.4 | G0/G1, G2/G3, Look-Ahead, Genauigkeit | CNC (TF5200) | cnc/ | CNC offen | Abnahme am Prüfteil |
| LH-2.6.1 | Werkzeugtabelle einheitlich | TF5310 | HMI/CNC | CNC/HMI | – |
| LH-2.6.2 | Manueller Werkzeugwechsel M6 | FB_ToolChange | 4_Machine | Logik | T-TOOL-01 |
| LH-2.7.1 | Spindel ein/aus und Richtung | FB_Spindle | 2_Devices | Logik | T-SPN-01 |
| LH-2.7.2 | Drehzahl 0 bis 16600 1/min über FU | FB_Spindle (0 bis 10 V) | 2_Devices | Logik, Ansteuerung offen | T-SPN-02 |
| LH-2.8.1 bis 2.8.4 | G-Code DIN 66025 aus Fusion, große Programme | CNC, Streaming-Frage offen | cnc/ | CNC offen | Fusion-Testprogramm |
| LH-2.9.1 | Meldungen in Klartext mit Abhilfe | Meldekatalog, Texte in HMI | 5_Messages, HMI | Logik/HMI | T-ALM-01 |
| LH-2.9.2 | Meldehistorie | FB_AlarmJournal (ohne Zeitstempel/Persistenz) | 5_Messages | Teilweise | T-ALM-03 |
| LH-2.10.1 | Antriebsfreigabe nur bei Sicherheitskreis | FB_SafetyMonitor, FB_MachineState | 4_Machine | Logik, Verdrahtung offen | T-SAF-01 |
| LH-2.10.2 | Verhalten bei Not-Halt und Tür | Zustand EStop, Meldungen 100/101 | 4_Machine | Logik | T-SAF-02 |
| LH-2.10.3 | Wiederanlauf nur nach Quittierung | FB_SafetyMonitor, FB_AlarmList | 4_Machine, 5_Messages | Logik | T-SAF-03 |
| LH-2.10.4 | Überwachung Feldbus/Antriebe, definiertes Ausfallverhalten | FB_AxisSupervisor, Meldungen 300 bis 310 | 2_Devices | Logik | T-AXS-03 |
| LH-2.11.1/2 | Fernzugriff gesichert, nur nach Freigabe | Netz/Router, kein SPS-Code | – | offen | – |
| LH-2.11.3 | Sicherung Programme, Werkzeug, Parameter | Git für Software, Dateisicherung offen | – | offen | – |
| LH-2.11.4 | Ein Software-Stand für alle Maschinen | Maschinenparameter, FB_ParamCheck | 4_Machine, config/ | Logik | T-PAR-01 |

## Bewusst nicht in der Grundversion

Soll- und Kann-Funktionen (Einzelsatz-Details, Wiederaufnahme ab Satz, Werkzeuglängenmessung, Benutzerrollen,
Wartungsanzeige, TwinSAFE, OPC UA, Englisch) folgen nach dem Gutachten. Das Gleiche gilt für Sonderanforderungen.
