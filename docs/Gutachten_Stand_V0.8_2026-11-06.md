# Gutachten gebauter Stand: TwinCAT-Steuerung P-016 (CPU V0.8)

Stand: 06.11.2026. Geprüft: Commit `f970691` (Branch `claude/project-thread-hr9kgm`, PR #1), Export aus dem TwinCAT-Projekt `C:\Beckhoff\TwinCAT\P016`. HMI: Spezifikation im Branch `claude/project-thread-v7sp2u` (`hmi/`).
Unabhängige Prüfung durch einen dritten Thread, ohne Beteiligung am Code. Nichts geändert, nichts gebaut, nichts aktiviert.

**Grundlage und Grenzen.** Geprüft wurden alle `.st`-Dateien unter `twincat/PLC/src/`, `docs/`, `config/M1.json`, `test/` und die HMI-Spezifikation. Nicht eingesehen: das TwinCAT-Projekt selbst, das gebaute HMI-Projekt `P016_HMI`, `Doku/Stand_CPU.md`, `Doku/Stand_HMI.md`, `Doku/Test_Simulation_Ergebnis.md` (liegen nur auf dem Laptop). Der Repo-Export gilt laut README als abgeglichen. Abweichungen zwischen Export und Projekt sind nicht geprüft.

**Methode.** "Bestätigt" = Zyklus für Zyklus am Code durchgespielt. "Vermutung" = hängt von CNC (Tc2_CncHli), HMI, Hardware oder Schaltplan ab. Pfade relativ zu `twincat/PLC/src/`. IDs `G-01` usw., Bezug auf die Papierprüfung als "PB n".

## Kurzurteil

1. Die 23 Befunde der Papierprüfung sind weitgehend umgesetzt. Die Maschine kommt in der Simulation aus dem Fehler, referenziert, tippt, und es gibt keinen Selbstanlauf von Spindel und Tippen nach Quittierung. Das ist im Simulationstest belegt.
2. **Neu und kritisch:** Durch die Umstellung Endschalter R4 auf R3 mit Freifahren (PB 15) stoppt das Tippen beim Anfahren des Hardware-Endschalters nicht mehr. Die Achse fährt bei gehaltener Taste über den Endschalter hinaus (G-01).
3. Programmbetrieb ist noch nicht belastbar. Die CNC-Signale `bCncProgramActive`, `bCncProgramDone`, `rCncSpindleRpm` werden nirgends beschrieben. Mehrere Abläufe (Vorschubhalt, M3, Werkzeugwechsel, R4-Verzögerung) funktionieren deshalb nur auf dem Papier und haben Konzeptlücken (G-02 bis G-05).
4. Vor dem ersten Test an einer realen Maschine müssen G-01 bis G-07 erledigt oder bewusst entschieden sein.

## KRITISCH

**G-01. Tippen fährt über den Hardware-Endschalter hinaus (bestätigt, Sicherheit)**
- Stellen: `0_Main/PRG_Main.st:115-122`, `4_Machine/FB_Interlocks.st:30-31`, `4_Machine/FB_Jog.st:58-74`, `0_Main/GVL_AlarmCatalog.st:8` (Slot 10 = R3)
- Ablauf: Hand, Tippen+ gehalten, Achse erreicht den Endschalter. Im selben Zyklus wird `aCond[10]` TRUE. Weil keine andere R3/R4 ansteht, ist `bLimitFreeRun` sofort TRUE. `bJogOk` bleibt damit TRUE (`NOT bAnyR3OrHigher OR bLimitFreeRun`), `bDrivesEnabled` bleibt TRUE (R3 nimmt die Regler nicht weg). In `FB_Jog` bleibt `bActPlus` gesetzt, solange die Taste gedrückt ist. Die Tippanforderung an die CNC läuft weiter.
- Zusätzlich: Freifahren ist in beide Richtungen und auf allen Achsen erlaubt. "Schleichgang" ist nur das Abschalten von Eilgang, der normale Tippvorschub und `rJogStepMm` bleiben. Die Richtungssperre ist laut Kommentar `[offen]` in CNC oder Antrieb.
- Folge: Ob die Achse mechanisch auf Anschlag fährt, hängt allein davon ab, ob der iMD 40 oder die Verdrahtung den Endschalter selbst auswertet (Schaltplan fehlt). Die SPS bietet hier keinen Schutz mehr. Der Simulationstest erkennt das nicht, weil `FB_AxisMap_Simulation` die Endschalter fest auf TRUE setzt.
- Korrektur (CPU): Beim Kommen von Slot 10 laufendes Tippen sofort beenden und neue Flanke verlangen. Freifahren nur in Gegenrichtung der ausgelösten Seite und nur für die betroffene Achse, mit begrenztem Vorschub (CNC-Override oder eigener Tippvorschub). Dafür je Achse wissen, welcher Endschalter (+/-) anliegt; `bAnyHwLimit` reicht nicht. Test mit simuliertem Endschalter ergänzen.

## HOCH

**G-02. Vorschubhalt an die CNC ist nur ein Ein-Zyklus-Impuls (Vermutung zur CNC, Logik bestätigt)**
- Stellen: `4_Machine/FB_MachineState.st:47, 72, 89`, `0_Main/PRG_Main.st:207`
- `bCncHold` wird jeden Zyklus auf FALSE gesetzt und nur im Übergangszyklus nach Held TRUE. Im Zustand Held steht kein Halt mehr an. Beim Werkzeugwechsel ist der Halt dagegen ein Pegel (`fbTool.bHoldProgram`).
- Ist der Vorschubhalt der TwinCAT CNC über Tc2_CncHli ein Pegel (Bedieneinheit Feedhold, üblich), läuft das Programm nach einem Zyklus weiter, während SPS und HMI "Held" anzeigen. Das betrifft auch R2 (Absaugung, HMI-Verbindung) und M0. Endet das Programm dann, bleibt die SPS in Held, weil `rtDone` nur in Execute ausgewertet wird.
- Korrektur (CPU): `bCncHold` als Pegel ausgeben, solange `eState = Held`, und erst mit dem Fortsetzen zurücknehmen. HLI-Semantik von Start, Halt, Abbruch und Programmende bei der Anbindung dokumentieren.

**G-03. M3/M4 wird sofort quittiert, ohne dass die Spindel läuft (bestätigt)**
- Stellen: `3_Cnc/FB_MFunctions.st:40-41, 56`, `2_Devices/FB_Spindle.st:76-81, 100-102`
- `bAck := bMStrobe` quittiert jeden M-Code im selben Zyklus. Nach M3 fährt die CNC weiter, während die Spindel bis zu `tSpindleRunUp` (8 s) hochläuft oder gar nicht startet:
  - a) Spindel steht noch nicht (Auslaufzeit `tSpindleStandstill` 10 s nach dem letzten M5): Start wartet in `nDirPend`, das Programm schneidet bis zu 10 s mit stehender Spindel.
  - b) `bSpindleOk` FALSE: M3 wird verworfen und trotzdem quittiert, Programm läuft ohne Spindel weiter (PB 12, unverändert).
  - c) `bUnknown` wird gesetzt, aber nirgends ausgewertet (PB 12, unverändert). Ein unbekannter M-Code läuft still durch.
- Korrektur (CPU): Quittung für M3/M4 erst bei `fbSpindle.bRunning` (Drehzahl erreicht), mit Zeitüberwachung (Meldung 202). M3/M4 ohne Freigabe und unbekannte M-Codes als Meldung R3 mit Programmabbruch, nicht quittieren.

**G-04. Programmabbruch und NOT-HALT schalten das Vakuum ab, während die Spindel ausläuft (Vermutung: Vakuum = Werkstückspannung)**
- Stellen: `3_Cnc/FB_MFunctions.st:32-33`, `0_Main/PRG_Main.st:163, 184-186`, `4_Machine/FB_Interlocks.st:38`
- Jeder Abbruch, jede R3/R4 und jeder NOT-HALT setzt `bReset` und löscht das per M10 gehaltene Vakuum. NOT-HALT nimmt zusätzlich `bAuxOk` weg und damit auch das von Hand eingeschaltete Vakuum. Die Spindel läuft danach noch bis zu 10 s aus.
- Ist das Vakuum die Werkstückspannung (bei Formschaum naheliegend), wird das Teil gelöst, während das Werkzeug noch dreht oder im Material steht.
- Korrektur (CPU, mit Kunde klären): Vakuum bei Abbruch und NOT-HALT halten und nur durch M11, M30 oder Bedienhandlung im Stillstand abschalten. Klären, ob das Vakuumventil im Not-Halt-Kreis hängt (dann ist es Hardware und gehört in die Risikobeurteilung).

**G-05. Manueller Werkzeugwechsel bricht das Programm ab (Konzept, Vermutung zur Tür)**
- Stellen: `4_Machine/FB_SafetyMonitor.st:25`, `4_Machine/FB_MachineState.st:51-55`, `4_Machine/FB_ToolChange.st`
- Die Tür ist Teil von `bSafetyOk`. Muss der Bediener für M6 die Tür öffnen, geht die Maschine in EStop, `bAbortPending` bricht das Programm ab. Ein Wechsel mit Fortsetzen ist so nicht möglich.
- Nach dem Abbruch bleibt `fbTool.bRequest` stehen, weil nur `stCmd.bAbort` es löscht, nicht EStop oder R3. Folge: Spindel gesperrt, Programmstart und Betriebsartwechsel gesperrt, bis jemand "Werkzeug gewechselt" oder "Abbruch" drückt.
- Nach dem Wechsel startet die Spindel nicht wieder (M3 noch gesetzt, aber keine Flanke). Folgt im Programm kein neues M3, fährt es ohne Spindel weiter (siehe G-03).
- Korrektur (CPU und Kunde): Ablauf M6 mit Kunde festlegen (Tür, Zustimmtaster, Stillsetzen mit gehaltenen Achsen nach Stoppkategorie 2). `bRequest` bei Abbruch, R3 und EStop löschen. Nach M6 Spindel nur über neues M3 im Programm, mit Wartezeit nach G-03.

**G-06. Testprogramm `PRG_Test` läuft im Produktivstand und überschreibt Sicherheitseingänge (bestätigt als Konstruktion)**
- Stellen: `7_Weitere/MAIN.st:5`, `0_Main/PRG_Test.st:22, 30, 33-39`, `0_Main/GVL_Config.st:6-7`
- `MAIN` ruft `PRG_Test` vor `PRG_Main` in jedem Build auf. Gesperrt wird nur über die Konstante `bSimulationBuild`, die unabhängig von `eDriveVariant` gesetzt wird. Bleibt `bSimulationBuild` auf einer realen Maschine TRUE und wird `bTestEnable` online gesetzt, schreibt `PRG_Test` `bSafetyRelayFeedback`, `bDoorClosed`, `bFieldbusOk`, `bFuReady`, `bFuAtSpeed` auf TRUE. Auch mit `AT %I*` wirkt das im laufenden Zyklus, weil `PRG_Main` danach liest. Die SPS-Seite der Sicherheitsüberwachung wäre ausgehebelt (das Pilz-Relais bleibt wirksam).
- Korrektur (CPU): Test in eigene SPS-Instanz oder per bedingter Übersetzung (`{IF defined (...)}`) entfernen. Mindestens: `PRG_Test` nur bei `eDriveVariant = Simulation`, und `bSimulationBuild` daraus ableiten statt getrennt setzen. Die HMI zeigt `bSimulationActive` deutlich an (bitte im HMI-Projekt prüfen).

**G-07. Jede HMI-Sitzung kann Tippen und Spindel bedienen, auch Fernzugriff (Konzept)**
- Stellen: `6_Interfaces/ST_HmiCmd.st`, `4_Machine/FB_Jog.st:38-44`
- Die SPS kennt nur eine `stCmd`-Struktur und ein Lebenszeichen. Ein zweiter Browser (Büro, Fernwartung nach LH-2.11) kann Tippen, Spindel und Start schreiben, während das Panel das Lebenszeichen liefert. Ob das Lebenszeichen aus dem Panel-Client oder vom HMI-Server kommt, ist im Repo nicht erkennbar. Kommt es vom Server, läuft Tippen bei eingefrorenem Panel bis zum Loslassen weiter, das nie ankommt.
- Korrektur (HMI): Bedienbefehle nur vom lokalen Panel-Client zulassen (TwinCAT-HMI-Benutzerrechte, Client-Kennung oder IP), Fernzugriff nur lesend. Lebenszeichen im Client erzeugen. Die SPS sollte zusätzlich eine Client-Kennung prüfen (CPU).

## MITTEL

**G-08. R4-Verzögerung hält bei Gantry-Antriebsfehler die zweite Portalseite 500 ms aktiv (Vermutung)**
- Stellen: `4_Machine/FB_MachineState.st:113-115`, `0_Main/GVL_Config.st:19`
- Bei R4 in Execute bleiben alle Regler bis zu `tR4DriveOffDelay` an, damit die CNC geführt bremst. Fällt Y1 aus (300) oder hat Y1 Schleppfehler (301), läuft Y2 weiter, Portal verzieht sich. Bei Schleppfehler durch Kollision drückt die Achse weiter.
- Die Verzögerung ist in der Simulation nicht prüfbar, weil `bCncProgramActive` nie TRUE wird und die Freigabe deshalb sofort fällt.
- Korrektur (CPU): Verzögerung nur für Meldungen ohne Antriebsbezug (900, 310 ohnehin EStop). Bei 300/301 auf Gantry-Achsen sofort abschalten oder CNC-Schnellhalt. Mit Gantry-Parametrierung der CNC abstimmen.

**G-09. Abbruch kann ohne Rückmeldung der CNC hängen bleiben (Vermutung)**
- Stellen: `4_Machine/FB_MachineState.st:58, 98, 102-104`
- EStop und Fault werden nur verlassen, wenn `bAbortPending` gelöscht ist, also die CNC "kein Programm aktiv" meldet. Meldet die CNC nach Reglerabschaltung einen Fehler und bleibt "aktiv", gibt es keinen CNC-Reset-Befehl. Quittieren hilft nicht.
- Korrektur (CPU): CNC-Kanal-Reset als Teil der Quittierung vorsehen, Timeout mit eigener Meldung.

**G-10. Referenzverlust ist R1 und hält ein laufendes Programm nicht an (bestätigt)**
- Stellen: `0_Main/GVL_AlarmCatalog.st:8` (Slot 12 = 1), `2_Devices/FB_AxisSupervisor.st:42-52`
- Mit der Lösung von PB 5 ist 320 nur noch Warnung. Geht die Referenz in Execute verloren (Geberfehler, CNC meldet Achse nicht referenziert), läuft das Programm weiter.
- Korrektur (CPU): Klasse kontextabhängig: in Execute/Held R3, sonst R1.

**G-11. Spindel startet durch Umschalten der Drehrichtung (bestätigt)**
- Stellen: `0_Main/PRG_Main.st:167-168`, `2_Devices/FB_Spindle.st:76-81`
- Nach NOT-HALT und Quittierung steht `bSpindleOn` an, die Spindel steht (richtig). Schaltet der Bediener jetzt nur die Richtung um (`bSpindleCcw`), entsteht eine steigende Flanke an `bStartCcw`, die Spindel läuft an. Ebenso wartet eine Anforderung während des Auslaufs in `nDirPend` und startet bis zu 10 s später ohne weitere Bedienung.
- Korrektur (CPU, HMI): Hand-Start nur aus der Flanke von `bSpindleOn`; Richtung nur im Stillstand annehmen; wartende Anforderung verwerfen statt verzögert starten, HMI zeigt "Spindel läuft aus".

**G-12. Spindel "läuft" mit 0 V und Trockenlauf wirkt mitten im Programm (bestätigt)**
- Stellen: `2_Devices/FB_Spindle.st:89-93`, `0_Main/PRG_Main.st:166, 169`
- `rCncSpindleRpm` wird nie beschrieben. In Auto ist der Sollwert 0, die Spindel bekommt Startbefehl und 0 V. `rSpindleMinRpm` = 0 lässt das zu.
- `bDryRun` geht in `bSetupLocked` und stoppt die Spindel sofort, auch mitten im Schnitt; Abschalten startet sie nicht wieder. `bDryRun` sperrt auch in Hand und meldet dann irreführend 203 "im Einrichten gesperrt".
- Korrektur (CPU): Drehzahl unter Mindestdrehzahl (Herstellerangabe VKH63) als Fehler; S-Wert aus der CNC verdrahten. Trockenlauf nur bei Programmstart übernehmen und nur in Auto wirken lassen.

**G-13. Persistente Daten gehen bei Ausschalten am Hauptschalter verloren (Vermutung zur Hardware)**
- Stelle: `0_Main/GVL_Persistent.st:6-11`
- `VAR_GLOBAL PERSISTENT` wird nur beim geordneten Herunterfahren gespeichert. Ohne USV am CP2221 sind Maschinenkennung, Journal und Betriebsstunden nach Netz-Aus auf dem letzten gespeicherten Stand. Fehlt `nMachineId`, ist die Maschine gesperrt (900).
- Korrektur (CPU): USV/1-Sekunden-USV vorsehen (Bestellliste prüfen) oder `FB_WritePersistentData` zyklisch bei Änderung; `nMachineId` zusätzlich als Datei.

**G-14. Spindelstillstand nur über Zeit, Werkzeugwechsel-Aufforderung kommt sofort (bestätigt)**
- Stellen: `2_Devices/FB_Spindle.st:105-106`, `4_Machine/FB_ToolChange.st:25-31`, `0_Main/PRG_Main.st:245`
- "Stillstand" ist 10 s nach Wegnahme des Starts angenommen, ohne Rückmeldung vom FU. Ist die Auslauframpe am Commander SK länger oder steht er auf Austrudeln, gilt die Spindel als stehend, obwohl sie dreht. Die HMI zeigt die Aufforderung zum Werkzeugwechsel sofort, nicht erst nach Stillstand.
- Korrektur (CPU, Hardware): Relaisausgang "Drehzahl null" des Commander SK auswerten; Aufforderung erst bei Stillstand anzeigen.

**G-15. Referenzfahrt auf Endschalter bricht ab (Vermutung, Schaltplan)**
- Stellen: `4_Machine/FB_Interlocks.st:34`, `4_Machine/FB_Homing.st:46`
- Nutzen isel-Achsen den Endschalter als Referenzschalter (bei isel-Anlagen verbreitet), löst die Referenzfahrt Meldung 302 (R3) aus, `bHomingOk` fällt, die Referenzfahrt wird abgebrochen.
- Korrektur (CPU): Mit Schaltplan klären; ggf. Slot 10 während `fbHoming.bBusy` für die aktive Gruppe ausblenden.

**G-16. Werkzeugtabelle schreiben überschreibt die Nullpunkte (bestätigt)**
- Stelle: `3_Cnc/FB_CncMirror.st:44-48`
- `bTableWrite` übernimmt `aTool` und `aWcs` zusammen. Ist der Schreibpuffer `stCncCmd.aWcs` in der HMI nicht vorab aus `stCncSts` gefüllt (Startwert 0), setzt das Speichern der Werkzeugtabelle alle Nullpunkte G54 bis G59 auf 0. Später an der echten CNC: falscher Nullpunkt, Kollision.
- Korrektur (CPU, HMI): Getrennte Schreibimpulse für Werkzeug und Nullpunkt; HMI füllt den Puffer vor dem Bearbeiten.

**G-17. Ein-Zyklus-Impulse an den Antrieb (Vermutung, CANopen)**
- Stellen: `0_Main/PRG_Main.st:62`
- `bResetReq := stCmd.bAck` steht genau einen SPS-Zyklus an. Läuft die EL6751 mit längerem CANopen-Zyklus als die SPS, geht die Fehlerquittung (DS402 Controlword Bit 7) verloren.
- Korrektur (CPU): Reset als Pegel bis Fehler weg oder Mindestdauer (z. B. 50 ms) im Achsabbild.

**G-18. Parameterprüfung ist wirkungslos (bestätigt)**
- Stellen: `0_Main/PRG_Main.st:47-53`, `4_Machine/FB_ParamInit.st:33-34`, `0_Main/GVL_Config.st:8`
- Erwartete Kennung und geladene Kennung stammen aus derselben Quelle, erwartete und laufende Version (`'0.1.0'`) stehen beide im Code. `FB_ParamCheck` kann nie anschlagen. Die Version `'0.1.0'` passt nicht zum Projektstand V0.8.
- Korrektur (CPU): Version bei jedem Tag pflegen; Prüfung erst mit externem Parametersatz (Datei) sinnvoll, bis dahin als "Platzhalter" kennzeichnen.

**G-19. Achsnummerierung doppelt gepflegt (bestätigt)**
- Stellen: `0_Main/GVL_Config.st:14-17` (unbenutzt), `0_Main/PRG_Main.st:9, 75-80, 190-192, 259-261`
- Die zentralen Zuordnungstabellen aus PB 16 werden nirgends verwendet; `PRG_Main` hat eine eigene lokale Tabelle und fest codierte Indizes. Ändert sich die Achszuordnung nach dem Schaltplan, muss an vier Stellen gleich geändert werden.
- Korrektur (CPU): Nur `GVL_Config`-Tabellen verwenden.

## NIEDRIG

**G-20. Sonstige Logik**
- `bCncProgramDone` geht als Pegel in `fbMFunc.bReset` (`PRG_Main.st:163`). Bleibt es nach Programmende bis zum nächsten Start stehen (HLI-Semantik offen), wird ein frühes M3 im neuen Programm verworfen.
- Programmstart prüft nicht `stCncSts.bProgramLoaded`.
- `eHomeState` bleibt nach Referenzverlust auf Done; HMI zeigt "referenziert", obwohl `bHomed` FALSE ist (PB 8f).
- `aOrder` in `FB_Homing` weiter nicht von außen einstellbar (PB 8e, LH-2.2.1).
- `rMaxFollowErr` fest 1.0 mm in `PRG_Main.st:82`, `bAllReady` ohne Auswertung (PB 14).
- Spindel-Override kommt einen Zyklus verspätet, weil `fbCncMirror` nach `fbSpindle` läuft.
- `eModeRequest` ohne Bereichsprüfung (PB 17); ein ungültiger Wert sperrt alles, ohne Meldung.
- Einrichtbetrieb ohne reduzierte Geschwindigkeit; mit Tür im Sicherheitskreis praktisch ohne Funktion (PB 17).
- Meldejournal: flatternder Endschalter füllt die 100 Einträge; nur "kommt", kein "geht".
- Ungenutzte Variablen: `bSimulation`, `nVersionDummy`, `tonSpindleUptime`, `dwSecTick`, `aHomeReq`-Duplikat, `bAirOk` in `FB_SafetyMonitor`. Indizes in `aCond` weiter als Zahlen statt `E_AlarmSlot`.
- `rSpindleVolt` REAL ohne Skalierung auf den Klemmen-Prozesswert (PB 22).

**G-21. Dokumentation und Schnittstelle**
- `docs/Schnittstelle_SPS-HMI.md:14` sagt weiter "CNC-Werte aus TF5310", Zeile 21 und Tabelle (Z. 31, 37, 39) nennen 200, 302, 320 als R4. Der Katalog hat 200 = R3, 302 = R3, 320 = R1.
- HMI `hmi/spec/alarm-texts.de.json` (Branch `v7sp2u`, Z. 33, 75, 89) und Bildschirmtabelle: dieselben veralteten Klassen. Abhilfe-Text für 320 und 100 fordert Neureferenzieren, was nach PB 5 nicht mehr zwingend ist. Die HMI sollte die Klasse aus `stSts.aAlarms[].eClass` anzeigen, nicht aus der JSON.
- `README.md:10-13` sagt "kein TwinCAT-Projekt, kein Build", Z. 48-54 das Gegenteil.
- `docs/Anforderungen_Grundfunktionen.md`: Testfall-IDs T-MODE-01 usw. existieren nicht, `PRG_Test` nutzt T01 bis T14. Status "Logik" für LH-2.4.2, 2.4.4, 2.7.2 weiter zu hoch (siehe G-02, G-03, G-12).
- `docs/UEBERGABE_CPU-Thread.md` und `test/README.md` beschreiben den Stand vor dem Build. `test/plc/FB_Test_SafetyMonitor.st` ist nicht im Projekt und nicht ausgeführt.

## Offen wegen Hardware (kein Code-Fehler, aber Voraussetzung)

- Kein hardwarewirksamer Ausgang für "SPS nimmt Freigabe weg" (PB 9). Heute wirkt die SPS nur über das Controlword.
- Z-Bremse: kein Ausgang, keine Ansteuerung. R4 und NOT-HALT im Handbetrieb nehmen die Freigabe sofort weg; ohne Bremse fällt Z.
- Endschalter je Achse und Seite, Referenzschalter, Stoppkategorie Pilz, Rückmeldungen Commander SK: Schaltplan fehlt.
- Gantry-Überwachung (`rGantryDiffMm`) wird nicht berechnet; liegt in der CNC.

## Simulationstest `PRG_Test`: Bewertung und Lücken

Der Test belegt die Kernaussagen der PB 1, 6, 7 (kein Selbstanlauf) und die Grundabläufe in Hand. Er ist ein guter Rauchtest, aber kein Nachweis für Programmbetrieb.

**Schwächen der Methode**
- Prüfungen nur zu einzelnen Zeitpunkten. Ein kurzer Startimpuls (z. B. `bSpindleRun` oder `bCncJogPlus` für wenige Zyklen nach der Quittierung) zwischen zwei Prüfzeitpunkten fällt nicht auf. Besser: je Fenster einen Merker "trat auf" mitführen.
- Der simulierte FU meldet "Drehzahl erreicht" ohne Verzögerung (`PRG_Test.st:30`), Meldung 202 und Hochlauf sind nicht prüfbar.
- Simulierte Endschalter und Antriebsfehler fest auf "in Ordnung" (`FB_AxisMap_Simulation.st:20-23`), keine Einspeisung möglich.
- Keine CNC-Simulation: `bCncProgramActive`, `bCncProgramDone`, `nCncMCode`, `bCncMStrobe`, `rCncSpindleRpm` bleiben 0.

**Fehlende Testfälle (Vorschlag, in dieser Reihenfolge)**

| Nr. | Fall | Erwartung | Bezug |
|---|---|---|---|
| T15 | Tippen+ gehalten, Endschalter + kommt | Tippen stoppt sofort, Meldung 302, nur Tippen- frei, kein Eilgang | G-01 |
| T16 | Endschalter frei gefahren | Tippen stoppt beim Verlassen, Quittierung nötig | G-01 |
| T17 | Auto: Start, M3 S12000 (Strobe simuliert) | Quittung erst bei Drehzahl erreicht, Spannung 7,2 V | G-03, G-12 |
| T18 | Auto: Halt, 2 s warten | `bCncHoldReq` steht die ganze Zeit an | G-02 |
| T19 | Auto: Abbruch bei laufender Spindel | Spindel aus, `bCncAbortReq` bis `bCncProgramActive` FALSE, M3 gelöscht | PB 1, PB 4 |
| T20 | Auto: NOT-HALT in Execute, CNC meldet noch aktiv | EStop bleibt trotz Quittierung, bis CNC steht | PB 4, G-09 |
| T21 | Auto: Antriebsfehler Y1 in Execute, CNC aktiv | Freigabe fällt spätestens nach 500 ms, Zustand Fault | G-08 |
| T22 | Auto: M6, Bestätigung vor und nach Stillstand | vor Stillstand abgewiesen, danach Fortsetzen; kein Spindelstart | G-05 |
| T23 | Auto: R2 (Absaugung) in Execute, dann weg, Start | Held, Fortsetzen nur mit Start | Zustandsmaschine |
| T24 | Feldbus aus und wieder an | EStop, kein Wiederanlauf ohne Quittierung | PB 19 |
| T25 | Betriebsart wechseln bei laufender Spindel und in Held | abgewiesen, `bModeChangeBlocked` 3 s | PB 17 |
| T26 | Richtungsumschaltung bei stehendem `bSpindleOn` nach Quittierung | kein Start | G-11 |
| T27 | Referenzfahrt abbrechen, Einzelachse X ohne Z | Abbruch sauber, X abgewiesen | PB 8 |

Für T15 bis T22 braucht die Simulation einstellbare Endschalter und Fehler in `FB_AxisMap_Simulation` und einen kleinen CNC-Stub (Programm aktiv/fertig, M-Strobe, S-Wert), solange TF5200 nicht angebunden ist.

## Stand der 23 Befunde der Papierprüfung

| PB | Thema | Stand |
|---|---|---|
| 1 | Spindel-Selbstanlauf | behoben (Flanke, Hand-Sperre); Rest siehe G-11 |
| 2 | Parameter nie geladen | behoben (`FB_ParamInit`, Konstanten) |
| 3 | Referenzstatus | behoben (eine Quelle, Simulation) |
| 4 | NOT-HALT in Execute | behoben in der Logik; wirkt erst mit `bCncProgramActive` (HLI) |
| 5 | Referenzverlust-Deadlock | behoben; neue Folge G-10 |
| 6 | Tippen-Selbstanlauf | behoben, im Test belegt |
| 7 | `bLatched` beim Anlauf | behoben, T01 |
| 8 | Referenzfahrt | a bis d behoben, e und f offen (G-20) |
| 9 | Simulationsabbild | teilweise (Auswahl per Konstante); G-06, Hardware-Abschaltung offen |
| 10 | Drehzahl aus Programm | verdrahtet, Quelle fehlt (G-12) |
| 11 | Meldekatalog | eine Quelle; Zahlenindizes und Doku offen (G-20, G-21) |
| 12 | M-Funktionen | M1/M2, Quittung gehalten, M30 schaltet ab; `bUnknown`, M3 ohne Freigabe offen (G-03) |
| 13 | Spindel-Umkehr, Anzeige, HMI-Verlust | behoben |
| 14 | Antriebsüberwachung | Freigabe-Timeout und Reset da; `rMaxFollowErr`, `bAllReady` offen; G-17 |
| 15 | Endschalter R4, R4 abrupt | umgestellt; dabei neuer kritischer Fehler G-01; G-08 |
| 16 | Impulse, Achsnummern | SPS löscht Impulse, Achsnummer stabil; Tabellen unbenutzt (G-19) |
| 17 | Betriebsartwechsel | Wechsel und Rückmeldung behoben; Trockenlauf, Bereich, Einrichten offen (G-12, G-20) |
| 18 | Werkzeugwechsel | Bestätigung erst bei Stillstand; G-05, G-14 |
| 19 | Feldbus, Programmende | behoben (Feldbus im Sicherheitskreis, Flanke) |
| 20 | Kennung, Version | Kennung persistent; Prüfung wirkungslos (G-18) |
| 21 | Journal, Laufzeiten | behoben; Persistenz siehe G-13 |
| 22 | IEC/TwinCAT | Build fehlerfrei; Reste G-20 |
| 23 | Doku | teilweise; G-21 |

## Reihenfolge für CPU- und HMI-Thread

1. CPU: G-01 (Endschalter beim Tippen), G-06 (Test aus dem Produktivstand), danach Test T15/T16.
2. CPU: G-02, G-03 mit CNC-Stub und T17 bis T21; das klärt auch G-08, G-09 und G-12.
3. Mit Simon und Kunde klären: G-04 (Vakuum), G-05 (Ablauf M6 und Tür), G-07 (Fernzugriff), Einrichtbetrieb, Z-Bremse.
4. HMI: G-07, G-11 (Richtung nur im Stillstand), G-16 (Puffer füllen), G-21 (Klassen aus der SPS anzeigen).
5. Rest MITTEL und NIEDRIG beim nächsten Durchgang, danach Doku nachziehen.
