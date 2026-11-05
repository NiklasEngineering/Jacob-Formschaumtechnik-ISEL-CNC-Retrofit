# Schnittstelle SPS ↔ HMI (Steuerungssoftware-Seite)

Stand: 05.11.2026. Quelle der Wahrheit für die Typen: `twincat/PLC/src/6_Interfaces/`.
Die HMI-Seite pflegt die Bildschirmtabelle in `01_Konzept/06_Schnittstelle_SPS-HMI/` im Projektordner.

## Konvention

| Thema | Festlegung |
|---|---|
| Globale Variablen | `GVL_HMI.stCmd : ST_HmiCmd` (HMI → SPS), `GVL_HMI.stSts : ST_HmiSts` (SPS → HMI) |
| Impulse | Die SPS erkennt steigende Flanken selbst. Die HMI setzt Impulse für ≥ 1 Zyklus. |
| Lebenszeichen | `stCmd.nHeartbeat` wird von der HMI hochgezählt. Bleibt es länger als `tHmiTimeout` aus, stoppt Tippen und `stSts.bHmiLinkOk` wird FALSE. |
| Verriegelung | Nur in der SPS. Die HMI sperrt Tasten höchstens zusätzlich zur Anzeige. |
| CNC-Werte | Achspositionen, Overrides, Werkzeug- und Nullpunkttabelle liest die HMI direkt aus der CNC (TF5310-Datenmodell), nicht über `stSts`. |
| Meldungen | Meldekatalog `E_AlarmSlot`/IDs in `Alarm_Catalog.st`. Texte und Abhilfe pflegt die HMI-Seite, Klassen R0 bis R4 legt die SPS fest. |
| Einheiten | Positionen mm, Drehzahl 1/min, Zeiten ms |

## Fehlerklassen

R0 Hinweis, R1 Warnung, R2 Vorschubhalt (fortsetzbar), R3 Programmabbruch mit Spindel aus,
R4 Antriebe aus (Referenz verloren). R3 und R4 bleiben bis zur Quittierung gespeichert.

## Meldekatalog (Vorschlag der Klassen, mit Kunde abzustimmen)

| ID | Slot | Ursache | Klasse |
|---|---|---|---|
| 100 | SafetyOpen | Sicherheitskreis offen / NOT-HALT | R4 |
| 101 | DoorOpen | Tür offen | R3 |
| 110 | AirPressureLow | Druckluft zu niedrig | R3 |
| 120 | ExtractionFault | Absaugung ausgefallen | R2 |
| 200 | SpindleFuFault | FU-Störung | R4 |
| 201 | SpindlePtcTrip | Spindel-Kaltleiter Übertemperatur | R3 |
| 202 | SpindleNoFeedback | FU meldet Drehzahl nicht erreicht | R3 |
| 203 | SpindleLockedSetup | Spindelstart im Einrichten gesperrt | R1 |
| 300 | AxisDriveFault | Antriebsfehler | R4 |
| 301 | AxisFollowingErr | Schleppfehler | R4 |
| 302 | HwLimitHit | Hardware-Endschalter | R4 |
| 310 | FieldbusLost | Feldbus/EtherCAT ausgefallen | R4 |
| 320 | HomingLost | Referenz verloren | R4 |
| 330 | HmiLinkLost | HMI-Lebenszeichen fehlt | R2 |
| 900 | ParamMismatch | Maschinen-ID oder Version passt nicht | R4 |

[Annahme] Klassen sind Entwurf. Änderungen bitte hier und in `FB_AlarmList` gemeinsam machen.
