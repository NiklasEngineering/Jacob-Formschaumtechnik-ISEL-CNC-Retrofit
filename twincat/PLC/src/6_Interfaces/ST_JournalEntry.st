(* Eintrag im Meldejournal (Befund 21). Zeitstempel in UTC. *)
TYPE ST_JournalEntry :
STRUCT
    nId    : INT;      (* Meldungs-ID aus GVL_AlarmCatalog *)
    nClass : INT;      (* 0..4 = R0..R4 *)
    dtTime : DT;       (* Kommt-Zeitpunkt, UTC *)
END_STRUCT
END_TYPE
