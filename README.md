# Jacob Formschaumtechnik, ISEL-CNC-Retrofit (P-016): Steuerungssoftware

TwinCAT-3-Steuerungssoftware (SPS und CNC ohne Bedienoberfläche) für die Retrofit-Maschinen M1 bis M4.
Die Bedienoberfläche (TwinCAT HMI) wird getrennt entwickelt und nutzt die Schnittstelle in
`docs/Schnittstelle_SPS-HMI.md`.

## Stand

**Entwurf, nicht auf einer Maschine erprobt.** Die Quellen sind in Strukturiertem Text als `.st`-Dateien abgelegt
und mit `blark` auf Syntax geprüft. Es gibt noch kein TwinCAT-Projekt (`.tsproj`/`.plcproj`) und keinen
Build. Das Projekt wird auf dem Engineering-Laptop angelegt, sobald der MCP und TwinCAT XAE laufen;
die Dateien werden dann importiert.

## Sicherheitsregeln (verbindlich)

1. Die Sicherheitsfunktionen (NOT-HALT, Türen, Reglerfreigabe) bleiben fest verdrahtet im Pilz-Relais.
   Die SPS liest nur den Status und kann Freigaben nur zusätzlich wegnehmen. Der Code ist keine Sicherheitsfunktion
   im Sinne von ISO 13849.
2. Nichts wird von Claude oder per Skript auf eine reale Maschine aktiviert. Aktivieren auf der Maschine macht ein
   Mensch nach Review. Entwicklung und Test laufen gegen die Usermode Runtime am Laptop.
3. Wiederanlauf nie automatisch, immer mit Quittierung.
4. Keine Zugangsdaten, Lizenzen oder VPN-Schlüssel im Repo.

## Struktur

```
twincat/PLC/src/
  1_IO/          generische Achsschnittstelle, Abbildung je Antriebsvariante (CANopen, Analog, Simulation)
  2_Devices/     Spindel (weitere Geräte folgen: Absaugung, Ventile, Handrad)
  3_Cnc/         M-Funktionen (Anbindung CNC-HLI folgt)
  4_Machine/     Sicherheitsüberwachung, Betriebsarten, Zustand, Verriegelungen
  5_Messages/    Meldeliste, Klassenumwandlung
  6_Interfaces/  gemeinsame Typen, HMI-Strukturen, Maschinenparameter, Meldekatalog
cnc/             CNC-Parameter (folgt)
config/          Maschinenparameter je Maschine (M1.json mit nicht bestätigten Werten)
test/            TcUnit-Tests (noch nicht ausgeführt)
docs/            Schnittstelle SPS/HMI
```

## Offene Annahmen (Auswahl)

Siehe `config/M1.json`, Feld `offen`, und Kommentare `[Annahme]` / `[offen]` im Code. Wichtigste:
Antriebsanbindung (CANopen DS402 mit EL6751 im Interpolated Position Mode ist unbestätigt, Rückfall ±10 V),
Achszuordnung, Endschalter, Z-Bremse, Stoppkategorie des Pilz-Relais, Spindel-Ansteuerung am Commander SK
(Schaltplan liegt nicht vor).
