(* Meldekatalog, einzige Quelle fuer ID und Klasse je Slot (Befund 11). Slot-Nummer = Index in aCond,
   siehe E_AlarmSlot. Klassen: 0 Info, 1 Warnung, 2 Vorschubhalt, 3 Abbruch, 4 Antriebe aus.
   Slot 12 (Referenzverlust) ist R1, Slot 13 (HMI-Verbindung) R2. Texte pflegt die HMI-Seite. *)
VAR_GLOBAL CONSTANT
    aAlarmId    : ARRAY[0..14] OF INT := [100, 101, 110, 120, 200, 201, 202, 203, 300, 301, 302, 310, 320, 330, 900];
    (* Befund 15: 200 (FU-Stoerung) und 302 (Endschalter) sind R3 statt R4. Die Achsregler bleiben an,
       das Programm wird abgebrochen, vom Endschalter kann in Hand freigefahren werden. [Annahme, mit Kunde abstimmen] *)
    aAlarmClass : ARRAY[0..14] OF INT := [4, 3, 3, 2, 3, 3, 3, 1, 4, 4, 3, 4, 1, 2, 4];
END_VAR
