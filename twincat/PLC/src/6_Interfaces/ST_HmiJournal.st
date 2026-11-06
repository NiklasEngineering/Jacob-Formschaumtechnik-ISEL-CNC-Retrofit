(* Meldejournal fuer die HMI (Befund 21, LH-2.9.2). Ringpuffer der letzten 100 kommenden Meldungen.
   nHead zeigt auf den naechsten freien Platz, der juengste Eintrag steht bei (nHead + 99) MOD 100.
   nSeq zaehlt jeden neuen Eintrag hoch, die HMI liest nur bei Aenderung. *)
TYPE ST_HmiJournal :
STRUCT
    aEntry   : ARRAY[0..99] OF ST_JournalEntry;
    nHead    : UINT;
    nEntries : UINT;
    nSeq     : UDINT;
END_STRUCT
END_TYPE
