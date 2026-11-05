(* CNC-Spiegel fuer die HMI. Solange TF5310 (CNC-Datenmodell) nicht verfuegbar ist, liest und
   schreibt die HMI alle CNC-Werte ueber diese Strukturen (GVL_HmiCnc). Die SPS befuellt den Spiegel
   spaeter aus Tc2_CncHli bzw. der CNC, bis dahin aus der Simulation. Achsnummern der HMI:
   1 = X (Quer), 2 = Y (Portal, Gantry), 3 = Z. *)

TYPE ST_AxisMirror :
STRUCT
    rActPosMach : LREAL;    (* mm, Maschinenkoordinate *)
    rActPosWork : LREAL;    (* mm, Werkstueckkoordinate *)
    bHomed      : BOOL;
END_STRUCT
END_TYPE

TYPE ST_Tool :
STRUCT
    nNo     : UINT;
    sName   : STRING(31);
    rLength : LREAL;        (* mm *)
    rRadius : LREAL;        (* mm *)
END_STRUCT
END_TYPE

TYPE ST_Wcs :
STRUCT
    rX : LREAL;             (* mm, Nullpunktverschiebung *)
    rY : LREAL;
    rZ : LREAL;
END_STRUCT
END_TYPE

(* SPS -> HMI *)
TYPE ST_HmiCncSts :
STRUCT
    aAxis         : ARRAY[1..3] OF ST_AxisMirror;
    rGantryDiffMm : LREAL;                       (* Y1 minus Y2 *)
    nOvrFeed      : UINT;                        (* % *)
    nOvrRapid     : UINT;
    nOvrSpindle   : UINT;
    sProgramName  : STRING(80);
    nActBlock     : UDINT;
    nTotalBlocks  : UDINT;
    sBlockText    : ARRAY[0..6] OF STRING(80);   (* Index 3 = aktueller Satz *)
    rRestMm       : LREAL;
    rFeedAct      : LREAL;                       (* mm/min *)
    nActTool      : UINT;
    nActWcs       : UINT;                        (* 54..59 *)
    aTool         : ARRAY[1..32] OF ST_Tool;
    aWcs          : ARRAY[54..59] OF ST_Wcs;
    bProgramLoaded: BOOL;
    bTableWriteOk : BOOL;                        (* Rueckmeldung letzter Schreibvorgang *)
    bTableWriteRejected : BOOL;                  (* abgelehnt, z. B. Programm laeuft *)
END_STRUCT
END_TYPE

(* HMI -> SPS *)
TYPE ST_HmiCncCmd :
STRUCT
    nOvrFeed       : UINT;                       (* % 0..120 *)
    nOvrRapid      : UINT;                       (* % 0..100 *)
    nOvrSpindle    : UINT;                       (* % 50..120 *)
    sProgramSelect : STRING(255);
    bProgramLoad   : BOOL;                       (* Impuls, nur im Stillstand *)
    aTool          : ARRAY[1..32] OF ST_Tool;    (* Schreibpuffer *)
    aWcs           : ARRAY[54..59] OF ST_Wcs;
    bTableWrite    : BOOL;                       (* Impuls: Puffer uebernehmen *)
    bWcsSetCurrent : BOOL;                       (* Impuls: aktuelle Position als Nullpunkt von nActWcs *)
END_STRUCT
END_TYPE
