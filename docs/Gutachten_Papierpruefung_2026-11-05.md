# Gutachten Papierprüfung: TwinCAT-Steuerung P-016

Stand: 05.11.2026, geprüft wurde Commit 016adb6 (Branch `claude/project-thread-hr9kgm`).
Unabhängige Prüfung durch einen separaten Prüf-Agenten ohne Beteiligung an der Entstehung des Codes. Es wurde nichts geändert und nichts gebaut. Das ist kein Ersatz für Bau, Test und die spätere Gutachten-Runde im dritten Thread.

Geprüft: alle 28 `.st`-Dateien unter `twincat/PLC/src/`, der Test unter `test/plc/`, README, `docs/*.md`, `config/M1.json`.

**Methode.** "Bestätigt" = am Code Zyklus für Zyklus durchgespielt, ohne Annahme über Hardware. "Vermutung" = hängt von CNC, HMI, Hardware oder TwinCAT-Verhalten ab, das im Repo fehlt. Pfade relativ zu `twincat/PLC/src/`. `blark parse` läuft für alle `.st` außer `test/plc/FB_Test_SafetyMonitor.st` (Methoden nach dem Rumpf). blark prüft nur Grammatik.

## KRITISCH

**1. Spindel läuft nach Abbruch und nach Quittierung von selbst wieder an (bestätigt, Sicherheit)**
- Stellen: `3_Cnc/FB_MFunctions.st:33-43`, `2_Devices/FB_Spindle.st:52`, `4_Machine/FB_MachineState.st:37,77,83`, `0_Main/PRG_Main.st:90-93`
- Ursache: `FB_MFunctions` hält `bSpindleCw/Ccw` dauerhaft bis M5/M30. `FB_Spindle` hat keine Selbsthaltung (`bWantRun` ergibt sich jeden Zyklus neu). `bSpindleStop` ist in `FB_MachineState` Z. 37 jeden Zyklus FALSE und bei HMI-Abbruch nur einen Zyklus TRUE.
- A (Auto, M3 aktiv, Abbruch): Zyklus n `bSpindleStop` TRUE; Zyklus n+1 wieder FALSE, Zustand Aborted, `bSpindleOk` TRUE, `bSpindleCw` noch TRUE, Spindel läuft im Zustand Aborted weiter. LH-2.4.2 nicht erfüllt, obwohl die Matrix "Logik" meldet.
- B (NOT-HALT, Tür, FU-/PTC-Störung, Luftdruck): Spindel geht aus, M3 oder HMI-Pegelbit `bSpindleOn` bleibt stehen. Mit der Quittierung ist `bSpindleOk` wieder TRUE, Spindel startet im selben Zyklus. Automatischer Wiederanlauf per Quittierung, verstößt gegen README-Regel 3.
- C: Nach Abbruch gilt M3 weiter; nach 10 s Stillstand Hand und wieder Auto startet die Spindel ohne Programm.
- D: Programmende ohne M30 (M2 nicht behandelt, siehe 12) lässt die Spindel in Idle weiterlaufen.
- Korrektur: Spindelanforderung in `FB_Spindle` selbsthaltend; jeder Stopp (Release weg, Fehler, Abbruch, Moduswechsel, Werkzeugwechsel) löscht sie; neuer Start nur per Flanke oder neues M3. `fbMFunc.bSpindleCw/Ccw` bei Abbruch, R3, R4, EStop, Programmende zurücksetzen. HMI `bSpindleOn` als Flanke auswerten oder SPS quittiert und löscht das Bit.

**2. Parameter werden nie geladen, Maschine bleibt dauerhaft im Fehler (bestätigt, Blocker)**
- Stellen: `0_Main/GVL_Machine.st:3-4`, `0_Main/PRG_Main.st:34-36`, `4_Machine/FB_ParamCheck.st:15`
- `bParamsLoaded` und `stParams` werden nirgends beschrieben; kein Lader für `config/M1.json`, obwohl `ST_MachineParams.st` "geladen beim Start" behauptet.
- Folge: `bMismatch` immer TRUE, Meldung 900 (R4) dauerhaft, Zustand Fault, Quittierung hilft nicht. Alle Zeiten T#0: `FB_Jog` `tHmiTimeout`=0 lässt `bHmiLinkOk` dauerhaft FALSE (Meldung 330 steht, Tippen nie möglich); `FB_Spindle` `tRunUp`=0 liefert sofort `bNoFeedback`, `tStandstill`=0 meldet sofort Stillstand, `rSpindleMaxRpm`=0 hält 0 V.
- Korrektur: Lader/Initialisierer mit Werten aus M1.json; bei unplausiblen Werten (Zeit=0, MaxRpm<=0) bewusst sperren und melden; `nIdExpected` und Version nicht in PRG_Main hartkodieren (siehe 20).

**3. Referenzstatus wird nirgends erzeugt, kein Programmstart möglich, Referenzfahrt endet im Timeout (bestätigt, Blocker)**
- Stellen: `1_IO/FB_AxisMap_Simulation.st:14-20`, `2_Devices/FB_AxisSupervisor.st:37`, `0_Main/GVL_Machine.st:10`, `0_Main/PRG_Main.st:119`
- `aAxis[i].bHomed` wird von keinem Code gesetzt; `rActPos`, `rFollowErr` bleiben 0. `aCncHomed` ist nur deklariert.
- Folgen: `bAllHomed` immer FALSE, `bProgramStartOk` immer FALSE; `FB_Homing` läuft nach `tTimeout` (120 s) in Error. Zwei unverbundene Referenzquellen (`aAxis[].bHomed`, `aCncHomed`), im neuen Commit eine dritte (`ST_AxisMirror.bHomed`).
- Korrektur: eine einzige Quelle festlegen und verdrahten. Simulationsabbild: `bHomed` und `aCncHomed` nach verzögertem Abschluss von `bHomeCmd` setzen, Rücksetzen bei Antriebsfehler nachbilden.

## HOCH

**4. NOT-HALT/Tür in Execute: CNC bekommt weder Halt noch Abbruch, nach Quittierung direkt Idle (bestätigt)**
- Stellen: `4_Machine/FB_MachineState.st:40-45, 48-62, 65-86`
- Zyklus n: Relais FALSE, Zustand EStop (Z. 41); Block "Vorrang 2" wird wegen `IF eState <> EStop` übersprungen, CASE hat keinen EStop-Zweig, `bCncHold`/`bCncAbort` werden nie gesetzt. Bei Quittung: EStop → Stopped (Z. 44), im selben Zyklus Idle (Z. 67), `bEnableDrives` TRUE. SPS meldet Idle, CNC-Programm kann noch "läuft" sein.
- Korrektur: Beim Übergang nach EStop aus Execute/Held `bCncAbort` anfordern (Pegel bis CNC steht). EStop nur nach Rückmeldung "Programm beendet" verlassen oder über Aborted führen.

**5. Referenzverlust (320) verriegelt sich selbst, Neureferenzierung unmöglich; gewollte Neureferenzierung löst den Fehler aus (bestätigt)**
- Stellen: `2_Devices/FB_AxisSupervisor.st:40-47`, `4_Machine/FB_Interlocks.st:31`, `4_Machine/FB_MachineState.st:49-51, 88`
- `bHomingLost` bleibt TRUE bis alle Achsen referenziert sind; 320 ist R4 → Fault, `bEnableDrives` FALSE. `bHomingOk` verlangt aber `bDrivesEnabled` und kein R3+ → Deadlock bis SPS-Neustart.
- Gewollte Einzelachs-Neureferenzierung kann (Vermutung, üblich) das Homed-Flag zurücksetzen und wird als Verlust gewertet.
- Korrektur: R4 für 320 aufweichen oder Referenzfahrt in diesem Zustand ausdrücklich freigeben; gewollte Neureferenzierung (`fbHoming.bBusy`) ausblenden; `bHadHomed` nur bei unerwartetem Abfall auswerten.

**6. Tippen läuft nach Quittierung, Sicherheitskreis-Wiederkehr oder HMI-Rückkehr von selbst weiter (bestätigt für die Logik, HMI-Verhalten Vermutung)**
- Stelle: `4_Machine/FB_Jog.st:34-35`
- `bJogPlusReq` ist reiner Pegel (`bJogOk AND bHmiLinkOk AND bPlus ...`), keine Flanken-Scharfschaltung, keine Rücknahme von `stCmd`.
- 1: Jog+ gehalten, NOT-HALT, Quittieren, Jog+ noch gehalten → Achse fährt sofort an. 2: HMI stürzt bei gehaltener Taste ab, `stCmd.bJogPlus` bleibt TRUE, nach HMI-Neustart fährt die Achse an. Gleiches bei Heartbeat-Wiederkehr nach Timeout.
- Korrektur: Tippen nur nach neuer steigender Flanke bei `bJogOk` und `bHmiLinkOk`; bei Verlust Anforderungsbit intern sperren (Re-Arm erst nach FALSE).

**7. SafetyMonitor beim Anlauf nicht fail-safe initialisiert (bestätigt als Konstruktion)**
- Stelle: `4_Machine/FB_SafetyMonitor.st:15-31`
- `bLatched` Initialwert FALSE, nicht RETAIN. Sind die Eingänge im ersten Scan TRUE, ist `bDrivesAllowed` TRUE, Stopped → Idle, Antriebe ohne Quittierung frei. Verhinderung hängt nur davon ab, dass das Prozessabbild im ersten Zyklus noch 0 ist.
- Test (`test/plc/FB_Test_SafetyMonitor.st:13-20`) prüft das nicht; `Reset_Fb` besteht trivial.
- Korrektur: `bLatched : BOOL := TRUE;` (Anlauf erfordert Quittierung) plus Test.

**8. Referenzfahrt: Mehrfachfehler (bestätigt, Aussage zur CNC Vermutung)**
- Stellen: `4_Machine/FB_Homing.st:59-76`, `4_Machine/FB_Interlocks.st:31`
- a) Schon referenziert: `aHomed[nActiveGroup]` wird im selben Zyklus wie `bHomeCmd` TRUE ausgewertet; bereits referenzierte Gruppe ist sofort "Done" (Z. 68) ohne zu fahren. Bewusste Neureferenzierung wird still übersprungen. Handshake fehlt.
- b) Kein Flankenwechsel: `bHomeCmd` bleibt beim Gruppenwechsel Z→X→Y dauerhaft TRUE. Erwartet die CNC eine steigende Flanke (Vermutung), werden Gruppe 2 und 3 nie gestartet. Einen Zyklus Pause oder Handshake-Bit je Gruppe.
- c) Freigabe zu weit: `bHomingOk` fordert nur `eState <> Execute`; Referenzfahrt in Held und in Auto möglich, parallel zu Tippen (`bJogOk` und `bHomingOk` beide TRUE). Kein Verriegelungseintrag "Referenzfahrt läuft" für Tippen und Programmstart.
- d) Keine Z-zuerst-Prüfung bei Einzelachs-Referenzierung X oder Y.
- e) Reihenfolge nicht einstellbar: `aOrder` Eingang mit Standardwert, in PRG_Main nicht verbunden, kein Weg von der HMI. LH-2.2.1 nicht umgesetzt.
- f) `eHomeState` der anderen Gruppen wird nie auf Open zurückgesetzt.

**9. Simulations-Achsabbild ist unbedingt aktiv und meldet Antriebe als betriebsbereit (bestätigt)**
- Stellen: `0_Main/PRG_Main.st:25,45`, `1_IO/FB_AxisMap_Simulation.st:14-20`
- `bSimulation` (Z. 25) wird nie benutzt; PRG_Main ruft immer `FB_AxisMap_Simulation` auf, unabhängig von `E_DriveVariant`. Der Baustein meldet `bReady` TRUE, `bEnabled` nach 200 ms, `bFault` FALSE, Endschalter immer OK. Auf der Maschine wären Antriebsfehler und Endschalter praktisch deaktiviert (fail-unsafe). Kein Ausgang, der in Hardware die Freigabe wegnimmt; `bSafeEnable` wirkt nur als Software-Bit.
- Korrektur: Auswahl per Konstante/Compilerschalter; in realer Konfiguration Build-Fehler oder Sperre, solange die echte Abbildung fehlt.

**10. Drehzahl im Automatikbetrieb stammt nicht aus dem Programm (bestätigt)**
- Stelle: `0_Main/PRG_Main.st:94`
- `rSetRpm` kommt immer aus `stCmd.rSpindleSetRpm`, auch bei M3 aus dem NC-Programm. S-Wert der CNC wird nirgends gelesen, `rOverridePct` fest 100. "M3 S12000" läuft mit HMI-Wert; bei 0 dreht die Spindel mit 0 V und es kommt nach `tRunUp` Meldung 202. Der Spiegel `nOvrSpindle` ist nicht verbunden. Matrix führt LH-2.7.2 als "Logik".
- Korrektur: S-Wert (CNC) und Override in den Spindel-FB führen; HMI-Drehzahl nur in Hand.

**11. Meldekatalog und Zähl-Indizes an vier Stellen dupliziert, eine Stelle bereits falsch (bestätigt)**
- Stellen: `6_Interfaces/Types_Common.st:34-52`, `5_Messages/FB_AlarmList.st:21-22`, `0_Main/PRG_Main.st:22,52-66`
- `E_AlarmId` fehlt 330 (HmiLinkLost), kommt aber in Doku, `FB_AlarmList` und `PRG_Main` vor. `E_AlarmSlot` wird nirgends verwendet; `PRG_Main` indiziert `aCond[0..14]` mit Zahlen. IDs und Klassen sind in `PRG_Main`, `FB_AlarmList`, `E_AlarmId` und Doku einzeln gepflegt (heute übereinstimmend, kein Test).
- Korrektur: eine Quelle, Slot-Enum für die Indizierung, Test der Katalog und Doku vergleicht.

## MITTEL

**12. M-Funktionen: Lücken (bestätigt)** (`3_Cnc/FB_MFunctions.st`)
- M0 setzt `bProgramHalt` (Z. 32), in PRG_Main unbenutzt, Programm hält nicht. M1 und M2 nicht im CASE → "unbekannt". `bUnknown` wird nicht ausgewertet, keine Meldung. LH-2.4.4 überbewertet. M30 schaltet Absaugung und Vakuum nicht ab.
- `bAck` nur einen Zyklus lang (Z. 48); bei langsamerer/asynchroner CNC (Vermutung) geht sie verloren, Programm wartet ewig. Quittung bis zum Fallen des Strobe halten.
- M3/M4 ohne `bSpindleOk` werden still verworfen, aber quittiert; Programm läuft ohne Spindel weiter.
- Absaugung: Meldung 120 (R2, `PRG_Main:55`) sofort aktiv, weil die Rückmeldung nach Einschalten erst nach Hochlauf kommt. `tFeedbackTimeout` (`ST_MachineParams.st:14`) nirgends benutzt. M43 in Auto löst fast sicher einen Vorschubhalt aus.

**13. Spindel: Drehrichtungsumkehr ohne Halt** (`FB_Spindle.st:52-55`)
- Wechsel `bStartCw` → `bStartCcw` lässt `bWantRun` TRUE, `bDirCcw` kippt sofort, Umkehr ohne Stillstand (FU-Überstrom, Spindelschaden). Umkehr über Stillstand führen.
- `rActRpm` ist laut Kommentar der berechnete Sollwert, geht aber als `rSpindleActRpm` an die HMI und zeigt Drehzahl auch ohne Drehung.
- Hand: bei Ausfall des HMI-Lebenszeichens stoppt die Spindel nicht (nur Tippen und R2).

**14. Antriebsüberwachung unvollständig** (`2_Devices/FB_AxisSupervisor.st`)
- `bEnableCmd` (Z. 6) und `tonEnable` (Z. 25) unbenutzt: Fällt `bEnabled` ohne `bFault` ab, keine Meldung, kein Timeout für "Freigabe bleibt aus". `bAllReady` nicht ausgewertet.
- `bResetReq` (`ST_AxisDrive.st:17`) wird nirgends gesetzt; Antriebsfehler lassen sich nicht quittieren.
- `rMaxFollowErr` hartkodiert 1.0 mm (`PRG_Main.st:48`), ungefiltert; im Eilgang auf realen Achsen > 1 mm plausibel (Vermutung).

**15. R4 bei Endschalter, abrupte Reglerabschaltung (Konzept)**
- 302 ist R4. Achse steht auf dem Endschalter, `bJogOk` verlangt `bDrivesEnabled` und kein R3+: kein Weg, freizufahren.
- R4 nimmt die Freigabe sofort weg (`PRG_Main:44`, `FB_MachineState.st:88`), keine Verzögerung für geführte Bremsung/Bremsenfall. Z-Bremse und Gantry-Verzug offen (`[offen]`). R4 wird für viele harmlose Fälle verwendet (z. B. 200, 302), nicht nur für Referenzverlust.

**16. Impulse und Mehrfeld-Konsistenz über die HMI-Schnittstelle (Vermutung)**
- Impulse von mindestens einem Zyklus kann die HMI über ADS nicht garantieren; zu kurzer Impuls geht verloren, kritisch für Abbruch und Halt. SPS löscht das Bit nach Auswertung oder HMI hält mindestens zwei Zyklen.
- `nJogAxis` und `bJogPlus` werden getrennt geschrieben; Jog+ mit alter Achsnummer fährt kurz die falsche Achse (`FB_Jog.st:34-36`). Achsnummer beim Flankenstart festhalten, mehrere Zyklen stabil verlangen.
- Heartbeat-Timeout begrenzt Nachlaufstrecke auf `tHmiTimeout` × Eilgang (bei 500 ms einige 10 mm). Heartbeat muss aus dem UI-Hauptlauf kommen.
- `nJogAxis` (1=X, 2=Y, 3=Z) geht unverändert an die CNC (`PRG_Main:131`), Homing-Gruppen werden umgemappt (1=Z, 2=X, 3=Y), `aDrive` (1=Y1, 2=Y2, 3=X, 4=Z): vierfach unterschiedliche Nummerierung.

**17. Betriebsartenwechsel und Verriegelungen**
- `FB_Interlocks.bModeChangeOk` (Z. 37) nie verwendet. `fbMode` bekommt nur `bStandstill` (`PRG_Main:49`), das prüft weder Held noch Achsbewegung, Referenzfahrt, offene Werkzeugwechsel-Aufforderung. Kommentar in `FB_OpModeManager` ("alle Achsen stehen") stimmt nicht. Bei abgeschalteter Spindel (Setup/Trockenlauf) Wechsel Auto → Hand im Zustand Held möglich, danach Tippen und späteres Fortsetzen.
- `bChangeBlocked` hat kein Feld in `ST_HmiSts`; abgewiesene Befehle bleiben ohne Rückmeldung.
- `bDryRun` mitten im Programm umschaltbar, schaltet dabei die Spindel ab/an (`PRG_Main:91`).
- `eModeRequest` ohne Bereichsprüfung (Enum aus INT).
- Setup ohne Inhalt (kein reduzierter Vorschub, kein Einzelsatz-Zwang).

**18. Werkzeugwechsel** (`FB_ToolChange.st`, `FB_MFunctions.st`)
- M6-Quittung (`bAck`) geht im selben Zyklus an die CNC wie die Haltanforderung; CNC kann schon den nächsten Satz begonnen haben (Vermutung).
- Zustand bleibt Execute, während Wechsel angefordert ist; Bestätigung vor Ablauf der 10 s Auslaufzeit geht verloren (keine Rückmeldung).
- Nach Bestätigung läuft die Spindel mit dem noch stehenden M3 sofort an (siehe 1).

**19. Zyklus-, Feldbus- und Programmende-Effekte**
- `bSafetyOk` (`FB_SafetyMonitor.st:24`) berücksichtigt `bFieldbusOk` nicht. Bei Feldbusausfall stehen EtherCAT-Eingänge häufig auf letztem Wert (Vermutung); Watchdog-/WcState-Signale je Klemme nötig.
- `bProgramDone` ist ein Pegel (`FB_MachineState.st:78`); steht er beim nächsten Start noch an, springt Execute sofort zurück auf Idle.
- Zyklus-Versatz (`fbState.bEnableDrives` vor Aufruf gelesen) ist in Sicherheitsrichtung abgesichert (`bSafeEnable` aktuell); für R4 Abschaltung einen Zyklus später, dokumentiert akzeptabel.

**20. Parameter- und Konfigurationskonsistenz**
- `nIdExpected := 1` und Version `'0.1.0'` im Code (`PRG_Main:34-35, 164`), widerspricht LH-2.11.4 "ein Stand für alle Maschinen".
- `config/M1.json` kennt `antriebsvariante` und `nNumAxes`=4; `ST_MachineParams` kennt `antriebsvariante` nicht, `nNumAxes` ("NC-Achsen") nicht definiert, HMI zählt 3 Achsen. Nichts davon wird gelesen.

**21. Meldejournal und Statusfelder** (LH-2.9.2)
- `FB_AlarmJournal`: Daten nur in privaten VAR-Arrays (`aJId`, `aJTime`), kein Ausgang, keine HMI-Schnittstelle. `dtNow` nie beschrieben, `nEntries` nicht verwendet. Matrix sagt "Teilweise", tatsächlich ist die Historie von außen nicht lesbar.
- `dwSpindleSec` nie gesetzt, `tonSpindleUptime` unbenutzt, `dwOperatingSec` nicht persistent.

## NIEDRIG

**22. TwinCAT-/IEC-Konformität.** Kein sicherer Kompilierfehler gefunden. Mögliche Warnungen/Importprobleme (Vermutungen):
- `.st`-Dateien lassen sich nicht direkt in TwinCAT 3 importieren (TcPOU/TcDUT/TcGVL oder PLCopen XML nötig). Mehrere Typen pro Datei (`Types_Common.st`, `ST_AxisDrive.st`, `ST_HmiCnc.st`) aufteilen. Methoden im Test nur als TcPOU.
- Enums ohne `{attribute 'qualified_only'}`/`{attribute 'strict'}`. `E_AlarmId` und `E_AlarmSlot` haben identische Elementnamen (`SafetyOpen`, `DoorOpen`, ...), unqualifiziert Namenskonflikt. `E_HomeState.Open/Done/Error` riskant.
- Arrays als VAR_INPUT (`aCond`, `aId`, `aStartAxis`, `aHomed`, `aOrder`) erlaubt, aber Kopie bei jedem Aufruf; VAR_IN_OUT passt besser (wie `FB_AxisSupervisor`).
- Mehrfachaufruf derselben TON-Instanz im selben Zyklus (`FB_Jog:29,31`, `PRG_Main:145-146`) funktioniert, schwer lesbar.
- `rSpindleVolt` ist REAL (Volt); EL4002 erwartet INT-Prozesswert (0x7FFF = 10 V), Skalierung fehlt.
- Unbenutzte Variablen: `bSimulation`, `nVersionDummy`, `tonSpindleUptime`, `FB_AxisSupervisor.tonEnable`, `FB_Homing.nLast`, `bAirOk` am SafetyMonitor.

**23. Dokumentation und Schnittstelle**
- `docs/Schnittstelle_SPS-HMI.md:14` sagt, CNC-Werte liest die HMI direkt aus der CNC; der neue Commit führt `GVL_HmiCnc` als Spiegel ein. Doku veraltet.
- Spiegel unbefüllt, zwei Fallen: `ST_HmiCncCmd.nOvrFeed/nOvrRapid/nOvrSpindle` starten mit 0 % (Vorschub 0, Spindel unter Untergrenze 50 %); die Regeln "nur im Stillstand" und "SPS begrenzt Overrides" sind nicht implementiert; `bTableWriteRejected` wird nirgends gesetzt.
- Verweise auf nicht vorhandene Dateien: `docs/Architektur_Sicherheit.md` (`Types_Common.st:23`), `docs/Meldeliste.md` (`Alarm_Catalog.st:2`).
- Doku erklärt R4 als "Antriebe aus (Referenz verloren)", der Katalog nutzt R4 auch für NOT-HALT, FU-Störung, Endschalter.
- README beschreibt `test/plc` mit Meldeliste, Zustandsmaschine, Spindel; tatsächlich nur `FB_Test_SafetyMonitor.st`. Testfall-IDs der Matrix (T-MODE-01 bis T-PAR-01) existieren nicht.

## Sicherheitskonzept: Gesamtbild
- Der Code gibt keinen Weg frei, der Pilz-Relais, Tür oder Feldbus direkt übergeht. NOT-HALT oder offene Tür schalten Spindel, Tippen und Hilfsausgänge sofort ab; Initialwerte der Ausgänge sind FALSE.
- Gefährlich sind Wiederanläufe nach Quittierung (1, 6, 7), weil Anforderungen (M3, `bSpindleOn`, Jog-Bits) die Auslösung überleben. Widerspricht README-Regel 3.
- "Freigabe zusätzlich wegnehmen" existiert nur als Software-Bit, es fehlt ein hardwarewirksamer Ausgang.

## Tests
- Ein Test für einen FB, ungebaut, vermutlich nicht importierbar (blark scheitert). Er besteht trivial wegen des fehlenden Anlauf-Latch (7). Es fehlen: Ack bei offenem Kreis, Feldbus, gehaltenes Ack, Neustart, sowie jede Prüfung von `FB_MachineState`, `FB_AlarmList`, `FB_Spindle`, `FB_Homing`, `FB_Jog`, `FB_MFunctions`.
- Die gefundenen Fehler liegen im Zusammenspiel in `PRG_Main` (Selbsthaltung, Reihenfolge, Zyklusversatz). Nötig: Integrationstest mit Stub für Eingänge, Parameter, CNC, Referenzstatus; TON-Logik mehrzyklisch oder mit injizierbarem Zeitgeber.
- TcUnit-Ablauf (Methodenreihenfolge, `Reset_Fb()` zwischen Tests) ungeprüft.

## Zusammenfassung
1. Der Stand taugt noch nicht als Grundlage für eine Simulation: Maschine kommt nie aus dem Fehlerzustand, kein Programm startbar (Parameter nie geladen, Meldung 900 R4; Referenzstatus nirgends erzeugt).
2. Sicherheitsarchitektur (SPS nimmt nur zusätzlich weg) im Ansatz richtig, aber belegte Fehler in der Zustandslogik: Spindel und Tippen laufen nach Abbruch/Quittierung wieder an, CNC bekommt bei NOT-HALT in Execute keinen Halt/Abbruch, Referenzverlust verriegelt sich selbst.
3. Zuerst beheben: Selbsthaltung/Zurücksetzen von Spindel- und Jog-Anforderungen (1, 6), `bLatched := TRUE` (7), EStop-Abbruchpfad (4), Referenz-Deadlock (5).
4. Danach die Simulations-Blocker: Parameterlader, einheitlicher Referenzstatus mit simuliertem Referenzieren (2, 3, 8), Auswahl und Absicherung der Simulationsabbildung (9), Integrationstest von `PRG_Main`.
5. Mehrere Matrixpunkte stehen zu Unrecht auf "Logik" (LH-2.4.2, 2.4.4, 2.7.2, 2.9.2, 2.2.1, 2.11.4). Kompilierbarkeit und CNC-Anbindung lassen sich erst nach Bau und Testlauf belastbar beurteilen.
