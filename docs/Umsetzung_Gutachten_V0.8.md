# Umsetzung Gutachten V0.8 (Stand V0.11, 06.11.2026)

Bezug: docs/Gutachten_Stand_V0.8_2026-11-06.md (PR #2). Nachweis: Simulationstest PRG_Test, 0 Fehler in zwei aufeinanderfolgenden Laeufen
auf frisch gestarteter Runtime (Tests T01 bis T22, siehe Test_Simulation_Ergebnis.md). Programmbetrieb laeuft gegen einen CNC-Stub, nicht gegen die echte CNC (TF5200 nicht angebunden).

| ID | Thema | Stand |
| :--- | :--- | :--- |
| G-01 | Tippen ueber Endschalter | **behoben**: Tippen stoppt je Seite sofort, neue Flanke noetig, Richtung zum Endschalter gesperrt, Freifahren nur Gegenrichtung ohne Eilgang und nur an der betroffenen Achse (T15 bis T17). [Annahme] Jog+ faehrt zur Plus-Seite. Schleichgang als Anforderung `GVL_Machine.bCncJogCreep`, Wirkung erst mit CNC-Anbindung. |
| G-02 | Vorschubhalt nur Impuls | **behoben**: Pegel, solange Held; Programmende in Held fuehrt nach Idle (T20). HLI-Semantik bei Anbindung klaeren. |
| G-03 | M3/M4 sofort quittiert | **behoben in der Logik**: Quittung erst bei laufender Spindel, nicht bei bewusst gesperrter Spindel (Einrichten, Trockenlauf), nicht quittiert wenn nicht ausfuehrbar (T19). **Offen:** unbekannter M-Code wird nicht quittiert, hat aber keine eigene Meldung. |
| G-04 | Vakuum bei Abbruch/NOT-HALT | **vorsichtig entschieden, Kundenfrage offen**: Vakuum bleibt gehalten, geht nur mit M11, M30/M2 oder von Hand aus (T21, T22). |
| G-05 | Werkzeugwechsel bei Abbruch | **teilweise**: Anforderung wird bei Abbruch, R3 und NOT-HALT geloescht. Spindelstart nach M6 nur ueber neues M3. Ablauf bei offener Tuer ist Kundenfrage. Nicht einzeln getestet. |
| G-06 | PRG_Test im Produktivstand | **behoben**: Test laeuft nur mit Simulationsabbild, `bSimulationBuild` ist aus `eDriveVariant` abgeleitet, Einspeisung (Endschalter, Fehler) wirkt nur im Simulationsabbild. **Offen vor Hardware:** Test per Compilerschalter oder eigene Instanz ganz entfernen. |
| G-07 | Bedienen von jeder HMI-Sitzung | **offen**: HMI-Rechte (nur lokales Panel bedient, Fernzugriff lesend), SPS-Client-Kennung. Kundenfrage. |
| G-08 | R4-Verzoegerung bei Gantry-Fehler | **offen**: haengt an Gantry-Parametrierung der CNC. |
| G-09 | CNC-Reset bei haengendem Abbruch | **offen**: braucht CNC-Anbindung. |
| G-10 | Referenzverlust im Programm | **behoben**: im laufenden oder gehaltenen Programm wirkt er wie R3, sonst Warnung R1. Nicht einzeln getestet. |
| G-11 | Spindel durch Richtungsumschaltung | **behoben**: Richtung wird beim Einschalten festgehalten, Hand-Start waehrend des Auslaufs wird verworfen, nur das Programm darf warten. |
| G-12 | S-Wert 0 / Trockenlauf | **teilweise**: Start ohne gueltigen S-Wert (<= 0) wird nicht angefahren, Meldung 202 (R3). Trockenlauf gilt nur in Auto und nur wie beim Programmstart. Mindestdrehzahl aus Herstellerangabe offen. S-Fehlerfall nicht einzeln getestet. |
| G-13 | Persistente Daten ohne USV | **offen**: Hardware (USV), Bestellliste pruefen. |
| G-14 | Spindelstillstand nur ueber Zeit | **offen**: Relais "Drehzahl null" des Commander SK, Schaltplan. |
| G-15 | Referenzfahrt auf Endschalter | **offen**: Schaltplan. |
| G-16 | Werkzeugtabelle ueberschreibt Nullpunkte | **behoben in der SPS**: `bTableWrite` nur Werkzeuge, neuer Impuls `bWcsTableWrite` nur Nullpunkte. **HMI muss umstellen.** |
| G-17 | Ein-Zyklus-Reset an den Antrieb | **offen**: mit CANopen/EtherCAT-Abbildung. |
| G-18 | Parameterpruefung wirkungslos | **teilweise**: Version bei jedem Stand mitgepflegt (0.11.0). Pruefung bleibt Platzhalter bis externer Parametersatz da ist. |
| G-19 | Achsnummerierung doppelt | **teilweise**: Antrieb-zu-Gruppe-Zuordnung kommt aus `GVL_Config`. Jog-Endschalterzuordnung nutzt noch feste Indizes. |
| G-20 | Sonstiges | **offen**, siehe Gutachten (`aOrder`, `rMaxFollowErr`, Journal-Flattern, unbenutzte Variablen). |
| G-21 | Doku/Schnittstelle | **teilweise**: README, Doku auf dem Laptop aktualisiert. Schnittstelle SPS/HMI und Alarmtexte (HMI-Thread) noch auf alte Klassen. |

## Neue Schnittstellenfelder (fuer den HMI-Thread)
- `ST_HmiCncCmd.nSpeedLimitPct` (UINT, 1..100, Start 25): Inbetriebnahme-Begrenzung, Anheben nur im Stillstand. `ST_HmiCncSts.nSpeedLimitActivePct`: wirksamer Wert, `nOvrFeed`/`nOvrRapid` sind damit bereits begrenzt.
- `ST_HmiCncCmd.bWcsTableWrite` (Impuls): schreibt nur die Nullpunkte. `bTableWrite` schreibt nur noch Werkzeuge.
- Meldeklassen: 200 und 302 R3, 320 R1 (Referenzverlust im Programm wirkt wie R3).

## Drei Kundenfragen (offen)
1. Vakuum: Werkstueckspannung? Im NOT-HALT-Kreis? (SPS haelt es bis auf weiteres.)
2. M6 bei offener Tuer: Wechsel mit Zustimmtaster und gehaltenen Achsen zulassen?
3. Fernzugriff: nur lesen oder auch bedienen? (Empfehlung: nur lesen.)

## Hinweis zum Test
Der Simulationstest ist gegen aeussere Schreibzugriffe empfindlich: Laeuft gleichzeitig ein HMI-Client, der Lebenszeichen oder Kommandos schreibt, schlagen einzelne Pruefungen sporadisch fehl (beobachtet in zwei Laeufen, zwei saubere Laeufe danach). Test ohne laufende HMI-Clients fahren.
