(* Generische Achsschnittstelle. Die Maschinenlogik kennt nur diese Struktur.
   Variante A: CANopen DS402 ueber EL6751 (Hauptvariante, Interpolated Position unbestaetigt)
   Variante B: +-10 V Analog + Encoder-Klemmen (Rueckfall)
   Die Zuordnung zu Klemmen/PDOs erfolgt ausschliesslich in FB_AxisMap_*. *)
TYPE E_DriveVariant :
(
    CanopenDs402 := 0,
    AnalogEncoder := 1,
    Simulation := 2
) INT;
END_TYPE

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
