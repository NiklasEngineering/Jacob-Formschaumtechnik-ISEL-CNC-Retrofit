# P-016 Schnittstelle SPS und HMI, Bildschirmtabelle (ENTWURF)

Stand 05.11.2026 · Maschine M1 (GPY 138/158-SW) · gepflegt vom HMI-Thread. Die Typen (Quelle der Wahrheit) liegen im Repo unter `twincat/PLC/src/6_Interfaces/` (SPS-Thread), Beschreibung `docs/Schnittstelle_SPS-HMI.md`.

Status: Vorschlag, nicht mit Kunde oder Beckhoff bestätigt. **Vor dem Ändern neu lesen.**

## Konvention

- `GVL_HMI.stCmd : ST_HmiCmd` (HMI an SPS), `GVL_HMI.stSts : ST_HmiSts` (SPS an HMI). Impulse erkennt die SPS per Flanke, die HMI setzt sie für mindestens einen Zyklus. `nHeartbeat` zählt die HMI hoch.
- Die HMI fordert nur an. Verriegelungen liegen in der SPS. Das HMI schaltet nie direkt Ausgänge oder Antriebe (Ausnahme: Service-Ausgangstest im Stillstand, Annahme).
- Logische Achsen für die HMI: 1 = X (Quer), 2 = Y (Portal, zwei Motoren Y1/Y2 als Gantry), 3 = Z. Zuordnung X/Y/Z **[Annahme]**. Die Antriebe 1..4 erscheinen nur in der Diagnose.
- Auf dem Laptop ist nur TF2000 installiert (kein TF5310, kein TF5200). CNC-Werte (Positionen, Overrides, Satz, Programm, Werkzeug- und Nullpunkttabelle) laufen deshalb über den Spiegel `GVL_HmiCnc.stCncSts : ST_HmiCncSts` und `stCncCmd : ST_HmiCncCmd` (SPS-Thread). Kommt TF5310 später, ändert sich nur die Befüllung in der SPS, die HMI-Bindung bleibt. Programm laden und Tabellen schreiben nur im Stillstand (Idle oder Hand), sonst `bTableWriteRejected`.
- Sicherheitsfunktionen bleiben hart verdrahtet. Die HMI zeigt nur Status. STOPP am Bildschirm ist ein Software-Stopp und ersetzt keinen Not-Halt.

Quelle: Cmd = `stCmd`, Sts = `stSts`, CncSts/CncCmd = `GVL_HmiCnc`, Param = `ST_MachineParams`, HMI = nur im HMI-Server. Status: **vorhanden** = Feld existiert in `ST_HmiCmd`/`ST_HmiSts`, **fehlt** = Wunsch an den SPS-Thread, Annahme, offen. Stand 05.11. 21:24: alle Wünsche der HMI bis auf aDI/aDO und getrennte Feldbuszustände sind in den Typen.

## In jedem Bild: Kopfzeile und Meldezeile

| Variable | Typ | Richtung | Quelle | Einheit / Hinweis | Status |
|---|---|---|---|---|---|
| stSts.nMachineId | UINT | S->H | Sts | z. B. 1 für M1 | vorhanden |
| stSts.eMode | E_OpMode | S->H | Sts | Hand, Auto, Setup | vorhanden |
| stSts.eState | E_MachState | S->H | Sts | Stopped, Idle, Execute, Held, Aborted, EStop, Fault | vorhanden |
| stSts.bSafetyOk | BOOL | S->H | Sts | Status Sicherheitskreis (Pilz) | vorhanden |
| stSts.bDrivesEnabled | BOOL | S->H | Sts | Reglerfreigabe | vorhanden |
| stSts.bAllHomed | BOOL | S->H | Sts | alle Achsen referenziert | vorhanden |
| stSts.bHmiLinkOk | BOOL | S->H | Sts | Lebenszeichen der HMI ok | vorhanden |
| stCmd.eModeRequest | E_OpMode | H->S | Cmd | Umschaltung, SPS verriegelt | vorhanden |
| stCmd.nHeartbeat | UINT | H->S | Cmd | HMI zählt hoch | vorhanden |
| Benutzer / Rolle | TwinCAT-HMI-Benutzerverwaltung | - | HMI | Bediener, Einrichter, Service | Annahme |
| stSts.nTopAlarmId / eTopAlarmClass | INT / E_FaultClass | S->H | Sts | höchste aktive Meldung | vorhanden |
| stSts.nActiveAlarms | UINT | S->H | Sts | Anzahl aktiv | vorhanden |
| stCmd.bAck | BOOL | H->S | Cmd | Impuls | vorhanden |

## Übersicht

Alle Betriebsdaten auf einen Blick. Startseite nach dem Anmelden und Rückfallseite bei Störung. Funktionsliste: 2.1.4, 2.9.3, 2.4.3. Mindestrolle: Bediener (Annahme).

| Variable | Typ | Richtung | Quelle | Einheit / Hinweis | Status |
|---|---|---|---|---|---|
| GVL_HmiCnc.stCncSts.aAxis[1..3].rActPosMach / rActPosWork | LREAL | S->H | CncSts | mm, 1=X 2=Y 3=Z; Y = Gantry-Paar | Annahme |
| stCncSts.rGantryDiffMm | LREAL | S->H | CncSts | mm, Y1 gegen Y2 | Annahme |
| stCncSts.aAxis[1..3].bHomed | BOOL | S->H | CncSts | zusätzlich stSts.bAllHomed | Annahme |
| stSts.bSpindleRunning / rSpindleActRpm | BOOL / REAL | S->H | Sts | 1/min, max. 16.600 | vorhanden |
| stSts.bExtractionOn / bBlowAirOn / bVacuumOn | BOOL | S->H | Sts |  | vorhanden |
| stCncSts.nOvrFeed / nOvrRapid / nOvrSpindle | UINT | S->H | CncSts | % | Annahme |
| stCncSts.sProgramName / nActBlock / nTotalBlocks / rFeedAct | STRING / UDINT / LREAL | S->H | CncSts |  | Annahme |
| Stückzähler Ist/Soll | UDINT | S->H | CncSts | nicht in der Grundversion, offen | offen |
| stCncSts.nActTool / nActWcs | UINT | S->H | CncSts | T-Nr., 54..59 | Annahme |

## Hand

Achsen verfahren per Touch oder Handrad, Schrittweiten, Eilgang, Spindel und Hilfsfunktionen. Funktionsliste: 2.3.1, 2.3.2, 2.3.3, 2.7.1, 2.7.4, 2.7.5. Mindestrolle: Einrichter (Annahme).

| Variable | Typ | Richtung | Quelle | Einheit / Hinweis | Status |
|---|---|---|---|---|---|
| stCmd.bJogPlus / bJogMinus / nJogAxis | BOOL / USINT | H->S | Cmd | gehalten, 1=X 2=Y 3=Z | vorhanden |
| stCmd.bJogRapid | BOOL | H->S | Cmd | Eilgang beim Tippen | vorhanden |
| stCmd.rJogStepMm | REAL | H->S | Cmd | 0 = kontinuierlich, sonst 0,01 / 0,1 / 1 / 10 mm | vorhanden |
| stCncCmd.nOvrFeed | UINT | H->S | CncCmd | 0..120 %, Tipp-Override zusätzlich offen | Annahme |
| stCmd.bHandwheelEnable / nHandwheelAxis / nHandwheelRatio | BOOL / USINT / USINT | H->S | Cmd | Achse 1=X 2=Y 3=Z, Untersetzung 1/10/100; nur M1 mit Bestandsgerät | vorhanden |
| stSts.bHandwheelActive | BOOL | S->H | Sts |  | vorhanden |
| stCmd.bSpindleOn / bSpindleCcw / rSpindleSetRpm | BOOL / BOOL / REAL | H->S | Cmd | nur Hand, 1/min | vorhanden |
| stCmd.bExtraction / bBlowAir / bVacuum | BOOL | H->S | Cmd |  | vorhanden |
| stCncCmd.bWcsSetCurrent | BOOL | H->S | CncCmd | Position als Nullpunkt; nur Stillstand, sonst bTableWriteRejected | Annahme |

## Referenz

Referenzfahrt aller Achsen oder einzeln, mit Anzeige der Sequenz. Funktionsliste: 2.2.1, 2.2.3, 2.2.6. Mindestrolle: Einrichter (Annahme).

| Variable | Typ | Richtung | Quelle | Einheit / Hinweis | Status |
|---|---|---|---|---|---|
| stCmd.bHomeRequest | BOOL | H->S | Cmd | Impuls, alle Achsen | vorhanden |
| stCmd.bHomeAxis[1..3] | BOOL | H->S | Cmd | Impuls, 1=X 2=Y 3=Z (SPS mappt intern) | vorhanden |
| stCmd.bHomeAbort | BOOL | H->S | Cmd | Impuls | vorhanden |
| stSts.bAllHomed | BOOL | S->H | Sts |  | vorhanden |
| stSts.eHomeState[1..3] | E_HomeState | S->H | Sts | Open, Running, Done, Error; Gantry: beide Seiten, dann Ausrichten | vorhanden |
| stSts.nHomeStep | USINT | S->H | Sts | Schritt der Sequenz für die Anzeige | vorhanden |
| stSts.aDrive[1..4].bHwLimitPlus / bHwLimitMinus | BOOL | S->H | Sts | Ruhestrom: FALSE = ausgelöst; Referenzschalter laut Schaltplan offen | offen |
| Alarm 320 HomingLost | E_AlarmId | S->H | Sts | Referenz verloren, Klasse R4 | vorhanden |

## Automatik

Programmlauf mit Satzanzeige, Overrides, Einzelsatz, Trockenlauf. Funktionsliste: 2.4.1, 2.4.2, 2.4.3, 2.4.4, 2.4.5, 2.4.6, 2.4.7, 2.4.8. Mindestrolle: Bediener (Annahme).

| Variable | Typ | Richtung | Quelle | Einheit / Hinweis | Status |
|---|---|---|---|---|---|
| stCmd.bStart | BOOL | H->S | Cmd | Impuls, startet und setzt fort | vorhanden |
| stCmd.bHold | BOOL | H->S | Cmd | Impuls, Vorschubhalt | vorhanden |
| stCmd.bAbort | BOOL | H->S | Cmd | Impuls, Programmabbruch | vorhanden |
| stCmd.bSingleBlock / bDryRun / bOptStop | BOOL | H->S | Cmd | Einzelsatz, Trockenlauf (Spindel gesperrt), optionaler Halt M01 | vorhanden |
| stCncCmd.nOvrFeed / nOvrRapid / nOvrSpindle | UINT | H->S | CncCmd | 0..120 / 0..100 / 50..120 %, SPS begrenzt | Annahme |
| stCncSts.nActBlock / sBlockText[0..6] / rRestMm | UDINT / STRING(80) / LREAL | S->H | CncSts | Index 3 = aktueller Satz | Annahme |
| stSts.eState | E_MachState | S->H | Sts | Execute, Held, Aborted | vorhanden |
| Laufzeit, Restzeit | TIME | S->H | CncSts | nicht in der Grundversion, offen | offen |
| stSts.bToolChangeReq / nToolChangeNo | BOOL / UINT | S->H | Sts | Aufforderung bei M6 | vorhanden |

## Programme

Programm aus dem Freigabeordner wählen und laden, Schnellauswahl. Funktionsliste: 2.8.4, 2.8.5, 2.1.6. Mindestrolle: Bediener (Annahme).

| Variable | Typ | Richtung | Quelle | Einheit / Hinweis | Status |
|---|---|---|---|---|---|
| Dateiliste Programmordner | Verzeichnisliste | S->H | HMI | Name, Größe, Datum; Pfad und Namenskonvention offen | offen |
| stCncCmd.sProgramSelect / bProgramLoad | STRING(255) / BOOL | H->S | CncCmd | nur im Stillstand (Idle oder Hand) | Annahme |
| stCncSts.bProgramLoaded / sProgramName | BOOL / STRING | S->H | CncSts | Syntaxfehler im Klartext offen | Annahme |
| Programm löschen | Aktion | H->S | HMI | nur Einrichter und Service | Annahme |
| Schnellauswahl 1..8 | ARRAY OF STRING | - | HMI | Serienfertigung, optional | Annahme |

## Werkzeuge

Werkzeugtabelle mit Nummer, Länge, Radius; manueller Werkzeugwechsel. Funktionsliste: 2.6.1, 2.6.2, 2.5.8. Mindestrolle: Einrichter (Annahme).

| Variable | Typ | Richtung | Quelle | Einheit / Hinweis | Status |
|---|---|---|---|---|---|
| stCncSts.aTool[1..32] / stCncCmd.aTool[1..32] + bTableWrite | nNo, sName, rLength, rRadius | S->H / H->S | CncSts | Schreibpuffer mit Impuls; nur Stillstand, Rückmeldung bTableWriteOk / bTableWriteRejected | Annahme |
| stSts.bToolChangeReq / nToolChangeNo | BOOL / UINT | S->H | Sts | M6 manuell: Programm hält, Aufforderung | vorhanden |
| stCmd.bToolChangeDone | BOOL | H->S | Cmd | Impuls, Quittung | vorhanden |
| Werkzeuglänge messen | BOOL | H->S | Cmd | nur mit Taster (EL1252), Option | offen |
| Werkzeugtabelle importieren, exportieren | Datei | - | HMI | Fusion-Bibliothek wäre Nachtrag | offen |

## Nullpunkte

Werkstücknullpunkte G54 bis G59 anzeigen, antasten, setzen. Funktionsliste: 2.2.2, 2.2.8. Mindestrolle: Einrichter (Annahme).

| Variable | Typ | Richtung | Quelle | Einheit / Hinweis | Status |
|---|---|---|---|---|---|
| stCncSts.aWcs[54..59] / stCncCmd.aWcs[54..59] + bTableWrite | rX, rY, rZ | S->H / H->S | CncSts | mm | Annahme |
| stCncSts.nActWcs | UINT | S->H | CncSts | 54..59 | Annahme |
| stCncCmd.bWcsSetCurrent | BOOL | H->S | CncCmd | nur Stillstand | Annahme |
| stCncSts.aAxis[1..3].rActPosMach | LREAL | S->H | CncSts | mm Maschinenkoordinaten | Annahme |

## Meldungen

Aktive Alarme mit Abhilfe, Historie, Quittieren. Funktionsliste: 2.9.1, 2.9.2, 2.10.2. Mindestrolle: Bediener (Annahme).

| Variable | Typ | Richtung | Quelle | Einheit / Hinweis | Status |
|---|---|---|---|---|---|
| stSts.aAlarms[0..14] | ST_Alarm | S->H | Sts | nId, eClass, bActive, bLatched; Index = Meldeslot; Zeit je Meldung kommt mit dem EventLogger-Adapter | vorhanden |
| Meldehistorie (Journal) | EventLogger-Abfrage | S->H | HMI | Filter nach Klasse und Datum | Annahme |
| stCmd.bAck | BOOL | H->S | Cmd | R3 und R4 bleiben bis zur Quittierung | vorhanden |
| Meldetexte und Abhilfe | Textkatalog de | - | HMI | Tabelle unten, ID wie E_AlarmId | Vorschlag |

## Diagnose

Achsstatus, Schleppabstand, Ein- und Ausgänge, Spindel und Feldbus. Funktionsliste: 2.9.3, 2.9.4, 2.10.4. Mindestrolle: Einrichter / Service (Annahme).

| Variable | Typ | Richtung | Quelle | Einheit / Hinweis | Status |
|---|---|---|---|---|---|
| stSts.aDrive[1..4].rFollowErr | LREAL | S->H | Sts | mm; Ist-Geschwindigkeit nicht vorgesehen | vorhanden |
| stSts.aDrive[1..4] | ST_AxisDrive | S->H | Sts | bReady, bEnabled, bFault, nFaultCode, rFollowErr; 1=Y1 2=Y2 3=X 4=Z [Annahme] | vorhanden |
| stSts.bFieldbusOk | BOOL | S->H | Sts | Sammelstatus, Alarm 310; getrennte Zustände EtherCAT/CANopen nicht vorgesehen | vorhanden |
| stSts.bFuFault / bPtcTrip | BOOL | S->H | Sts | Rohsignale, zusätzlich Alarme 200 und 201 | vorhanden |
| Druckluft, Absaugung | BOOL | S->H | Sts | über Alarme 110 und 120 | vorhanden |
| Digitale Ein- und Ausgänge | ARRAY OF BOOL | S->H | Sts | nicht in der Grundversion (SPS-Thread); Belegung fehlt (Schaltplan). Bild zeigt vorerst nur Statussignale | offen |
| Ausgangstest (Force) | BOOL | H->S | Cmd | nur Service, nur Stillstand, nie Sicherheitsausgang | Annahme |

## Service

Anmeldung, Parameter, Software-Endschalter, Wartung, Sicherung, Version. Funktionsliste: 2.1.7, 2.2.4, 2.9.5, 2.11.3, 2.11.4, 2.11.5. Mindestrolle: Service (Annahme).

| Variable | Typ | Richtung | Quelle | Einheit / Hinweis | Status |
|---|---|---|---|---|---|
| Anmeldung, Benutzer, Passwörter | Benutzerverwaltung | - | HMI | Bediener, Einrichter, Service | Annahme |
| Maschinenparameter | ST_MachineParams | S->H / H->S | Param | ein Software-Stand für M1 bis M4 | vorhanden |
| Software-Endschalter je Achse | LREAL | S->H / H->S | Param | mm, min und max; Feld in ST_MachineParams prüfen | offen |
| stSts.dwOperatingSec / dwSpindleSec | UDINT | S->H | Sts | Wartungsanzeige; Intervalle in ST_MachineParams | vorhanden |
| stSts.sSwVersion | STRING(15) | S->H | Sts | SPS-Stand; HMI- und Parameterstand zusätzlich | vorhanden |
| Sicherung, Wiederherstellung | Dateiaktion | - | HMI | Programme, Werkzeuge, Parameter | Annahme |
| Fernzugriff Freigabe | BOOL | H->S | Cmd | Umsetzung offen | offen |

## Wünsche an ST_HmiCmd und ST_HmiSts (Status "fehlt")


## Meldetexte und Abhilfe (Vorschlag, Klassen laut SPS-Thread)

| ID | Slot | Klasse | Text | Abhilfe |
|---|---|---|---|---|
| 100 | SafetyOpen | R4 | Sicherheitskreis offen oder NOT-HALT | Ursache beseitigen, NOT-HALT entriegeln, Türen schließen, quittieren, Achsen neu referenzieren |
| 101 | DoorOpen | R3 | Schutztür offen | Tür schließen, quittieren |
| 110 | AirPressureLow | R3 | Druckluft zu niedrig (unter 7,5 bar) | Druckluftversorgung prüfen, quittieren |
| 120 | ExtractionFault | R2 | Absaugung ausgefallen | Absaugung prüfen, Programm mit Start fortsetzen |
| 200 | SpindleFuFault | R4 | Spindelumrichter meldet Störung | Anzeige am Umrichter ablesen, Ursache beheben, quittieren |
| 201 | SpindlePtcTrip | R3 | Spindel zu heiß (Kaltleiter) | Spindel abkühlen lassen, Kühlung prüfen, quittieren |
| 202 | SpindleNoFeedback | R3 | Spindeldrehzahl nicht erreicht | Spindel und Umrichter prüfen, quittieren |
| 203 | SpindleLockedSetup | R1 | Spindelstart im Einrichten gesperrt | In Hand oder Automatik wechseln |
| 300 | AxisDriveFault | R4 | Antriebsfehler Achse | Fehlercode im Bild Diagnose lesen, beheben, quittieren, referenzieren |
| 301 | AxisFollowingErr | R4 | Schleppfehler zu groß | Achse auf Hindernis oder Klemmen prüfen, quittieren, referenzieren |
| 302 | HwLimitHit | R4 | Hardware-Endschalter angefahren | Achse im Hand freifahren, quittieren, referenzieren |
| 310 | FieldbusLost | R4 | Feldbus ausgefallen | Kabel und Teilnehmer prüfen, Steuerung neu starten |
| 320 | HomingLost | R4 | Referenz verloren | Alle Achsen referenzieren |
| 330 | HmiLinkLost | R2 | Verbindung zur Bedienoberfläche gestört | Bedienoberfläche neu starten |
| 900 | ParamMismatch | R4 | Maschinen-ID oder Version passt nicht | Service rufen, Parameter laden |
