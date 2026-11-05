# P-016 HMI (Bedienoberfläche M1)

Stand 05.11.2026, Entwurf. Gerät: Panel-PC CP2221, 21,5 Zoll, TwinCAT HMI (TF5310 CNC HMI Base, Rückfall TF2000).

| Ordner | Inhalt |
|---|---|
| `wireframes/` | HTML-Wireframes der 10 Bilder (auch als Artifact veröffentlicht) |
| `spec/` | `Bildschirmtabelle_SPS-HMI.md` (lesbar), `screens.json` (je Bild die Variablen, Quelle, Status), `alarm-texts.de.json` (Meldetexte und Abhilfe zu den Alarm-IDs der SPS) |
| `design/` | `tokens.css`, NIKLAS-Petrol |

## Aufbau jedes Bildes
Kopfzeile, Meldezeile, Arbeitsbereich, Funktionsleiste mit STOPP (Kapitel 4 der Softwaredokumentation).
Bilder: Übersicht, Hand, Referenz, Automatik, Programme, Werkzeuge, Nullpunkte, Meldungen, Diagnose, Service.

## Regeln
- Die HMI fordert nur an, Verriegelungen liegen in der SPS (`GVL_HMI.stCmd`, `stSts`, Typen in `twincat/PLC/src/6_Interfaces/`).
- CNC-Werte kommen direkt aus dem TF5310-Datenmodell.
- STOPP ist ein Software-Stopp und ersetzt keinen Not-Halt.
- Das eigentliche TwinCAT-HMI-Projekt (Visual Studio, Projekt P016_HMI auf dem Laptop unter `C:\Beckhoff\TwinCAT\P016`) wird in XAE erzeugt und danach hier abgelegt. Aus der Cloud ist es nicht erreichbar.

## Offen
Siehe Status `fehlt`, `offen` und `Annahme` in `spec/screens.json`.
