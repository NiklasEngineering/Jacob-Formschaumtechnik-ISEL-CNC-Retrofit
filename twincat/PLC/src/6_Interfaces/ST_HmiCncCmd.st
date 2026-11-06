(* HMI -> SPS *)
TYPE ST_HmiCncCmd :
STRUCT
    nOvrFeed       : UINT := 100;                (* % 0..120 *)
    nOvrRapid      : UINT := 100;                (* % 0..100 *)
    nOvrSpindle    : UINT := 100;                (* % 50..120 *)
    sProgramSelect : STRING(255);
    bProgramLoad   : BOOL;                       (* Impuls, nur im Stillstand *)
    aTool          : ARRAY[1..32] OF ST_Tool;    (* Schreibpuffer *)
    aWcs           : ARRAY[54..59] OF ST_Wcs;
    bTableWrite    : BOOL;                       (* Impuls: Puffer uebernehmen *)
    bWcsSetCurrent : BOOL;                       (* Impuls: aktuelle Position als Nullpunkt von nActWcs *)
    bWcsTableWrite : BOOL;                       (* Impuls: nur die Nullpunkte (G54..G59) aus aWcs uebernehmen. bTableWrite uebernimmt nur noch Werkzeuge (G-16) *)
    nSpeedLimitPct : UINT := 25;                 (* % 1..100, Inbetriebnahme-Begrenzung (Service). Wirkt nur nach unten auf Vorschub-/Eilgang-Override und Tippen. Anheben nur im Stillstand. *)
END_STRUCT
END_TYPE
