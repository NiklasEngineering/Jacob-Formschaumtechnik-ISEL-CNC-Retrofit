# Übergabe an den CPU-Thread (Laptop)

Stand: 05.11.2026, Branch `claude/project-thread-hr9kgm`, Pull Request #1 gegen `main`.

## Was vorhanden ist

SPS-Quellen als `.st` in `twincat/PLC/src/` (Ordner 0_Main bis 6_Interfaces), nur mit `blark` auf Syntax geprüft.
**Nie in TwinCAT gebaut, nie ausgeführt.** Beim Import sind Kompilierfehler zu erwarten (siehe unten).

| Ordner | Inhalt |
|---|---|
| 0_Main | `PRG_Main` (feste Aufrufreihenfolge), `GVL_IO`, `GVL_HMI`, `GVL_Machine`, `GVL_HmiCnc` |
| 1_IO | `ST_AxisDrive`, Achsabbild Simulation (fertig), CANopen (gesperrter Platzhalter) |
| 2_Devices | `FB_Spindle`, `FB_AxisSupervisor` |
| 3_Cnc | `FB_MFunctions` (CNC-Anbindung per Tc2_CncHli fehlt) |
| 4_Machine | Sicherheitsüberwachung, Betriebsarten, Zustand, Verriegelungen, Referenzfahrt, Tippen, Werkzeugwechsel, Parameterprüfung |
| 5_Messages | `FB_AlarmList` (R0 bis R4, Latching), `FB_AlarmJournal`, `F_ToFaultClass` |
| 6_Interfaces | Typen, `ST_HmiCmd`/`ST_HmiSts`, `ST_HmiCnc` (CNC-Spiegel), `ST_MachineParams`, Meldekatalog |

`docs/Anforderungen_Grundfunktionen.md` ordnet Anforderung, Baustein, Testfall und Status zu. `config/M1.json` hält Maschinenparameter mit Annahmen.

## Schnittstellenstand mit dem HMI-Thread

- `GVL_HMI.stCmd : ST_HmiCmd` und `GVL_HMI.stSts : ST_HmiSts` sind mit der HMI abgestimmt (Alarmliste, Antriebsdiagnose, Einzelachs-Referenz, Handrad, Einzelsatz, Trockenlauf).
- HMI-Achsnummern: 1 = X, 2 = Y, 3 = Z. `PRG_Main` bildet sie auf Referenzgruppen ab (1 = Z, 2 = X, 3 = Y).
- **Neu und noch nicht in der Logik:** `GVL_HmiCnc.stCncSts : ST_HmiCncSts` und `stCncCmd : ST_HmiCncCmd` als CNC-Spiegel (Positionen, Overrides, Programm, Satztext, Werkzeug- und Nullpunkttabelle), weil TF5310 auf dem Laptop fehlt. Typen sind abgestimmt, die Befüllung fehlt noch. Regeln: Programm laden und Tabellen schreiben nur im Stillstand, Overrides begrenzt die SPS (Vorschub 0..120 %, Eilgang 0..100 %, Spindel 50..120 %). Spindel-Override ist in `PRG_Main` noch fest 100 %.
- Meldetexte und Abhilfe pflegt die HMI-Seite in `01_Konzept/06_Schnittstelle_SPS-HMI/` (Projektordner).

## Bekannte Lücken und Annahmen

- Meldeklassen R0 bis R4 sind Entwurf, nicht mit dem Kunden abgestimmt.
- Achszuordnung (1 = Y1, 2 = Y2, 3 = X, 4 = Z), Referenzreihenfolge Z, X, Y, Endschalter, Z-Bremse, Stoppkategorie des Pilz-Relais, Spindelansteuerung am Commander SK (Start/Richtung, FU "Drehzahl erreicht"): alle ohne Schaltplan, als `[Annahme]` bzw. `[offen]` im Code.
- `FB_AxisMap_Canopen` ist bewusst gesperrt (Fehlercode FFFF0001), bis geklärt ist, ob die iMD 40 mit TwinCAT im Interpolated Position Mode laufen (DS402, kein CSP).
- Anbindung der CNC (Tc2_CncHli: M-Funktionen, Start/Halt/Abbruch, Tippen, Referenzieren, Overrides) ist nur als Variablen in `GVL_Machine` vorbereitet. TF5200 ist auf dem Laptop nicht installiert.
- `FB_AlarmJournal`: ohne Zeitstempel und Persistenz. `dtNow` wird nirgends befüllt.
- Betriebssekunden zählen ab Start, nicht persistent. Spindelstunden fehlen.
- Zeitgeber (Hochlaufzeit, Auslaufzeit) in `config/M1.json` sind geschätzt.
- `PRG_Main`: Sicherheits-Aufrufreihenfolge mit einem Zyklus Verzögerung (`fbState.bEnableDrives` wird vor dem Aufruf gelesen). Beim ersten Zyklus sind alle Ausgänge FALSE.
- `bSimulation` in `PRG_Main` ist ungenutzt, `GVL_IO` hat keine Adressen (`AT %I*`).
- TcUnit-Test nur für `FB_SafetyMonitor` (Methoden in `.st`, nicht gebaut).

## Zu erwartende Kompilierfehler und Hinweise

Strukturen mit Arrays in Zuweisungen (`aAlarms := fbAlarms.aList`, `aAxis := GVL_IO.aAxis`) sollten gehen; Arrays als `VAR_INPUT` von FBs ggf. in `VAR_IN_OUT` ändern. Enum-Zuweisung aus `INT` ist in `FB_AlarmList` bewusst über `F_ToFaultClass` gelöst. Wenn TwinCAT Methoden-Syntax verlangt (TcUnit-Test), den Test als `.TcPOU` neu anlegen.

## Regeln (unverändert)

Nichts auf eine reale Maschine aktivieren. Sicherheit bleibt im Pilz-Relais. Wiederanlauf nie automatisch. Alle Annahmen kennzeichnen.

## Gutachten

Ein unabhängiger Reviewer (Subagent ohne Vorwissen) prüft den Stand auf Papier. Sein Befundbericht wird als `docs/Gutachten_Papierpruefung_2026-11-05.md` nachgereicht und ist die Arbeitsliste für den CPU-Thread. Danach folgt die Prüfung durch den unabhängigen dritten Thread nach Build und Tests.
