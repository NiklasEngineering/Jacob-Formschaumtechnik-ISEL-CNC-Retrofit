(* Generische Achsschnittstelle. Die Maschinenlogik kennt nur diese Struktur.
   Die Zuordnung zu Klemmen/PDOs erfolgt ausschliesslich in FB_AxisMap_*. *)
TYPE ST_AxisDrive :
STRUCT
    (* Kommando (Logik -> Antrieb) *)
    bEnableReq   : BOOL;   (* Reglerfreigabe angefordert; wirkt nur mit Sicherheitsfreigabe *)
    bResetReq    : BOOL;
    (* Status (Antrieb -> Logik) *)
    bReady       : BOOL;
    bEnabled     : BOOL;
    bFault       : BOOL;
    nFaultCode   : UDINT;
    bHomed       : BOOL;
    bHwLimitPlus : BOOL;   (* Endschalter, Ruhestrom: FALSE = ausgeloest *)
    bHwLimitMinus: BOOL;
    rActPos      : LREAL;  (* mm *)
    rFollowErr   : LREAL;  (* mm *)
END_STRUCT
END_TYPE
