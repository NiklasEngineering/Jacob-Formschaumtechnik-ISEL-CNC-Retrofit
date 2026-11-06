(* CNC-Spiegel fuer die HMI, Achsnummern der HMI: 1 = X (Quer), 2 = Y (Portal, Gantry), 3 = Z. *)
TYPE ST_AxisMirror :
STRUCT
    rActPosMach : LREAL;    (* mm, Maschinenkoordinate *)
    rActPosWork : LREAL;    (* mm, Werkstueckkoordinate *)
    bHomed      : BOOL;
END_STRUCT
END_TYPE
