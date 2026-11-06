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
    nActWcs       : UINT := 54;                  (* 54..59 *)
    aTool         : ARRAY[1..32] OF ST_Tool;
    aWcs          : ARRAY[54..59] OF ST_Wcs;
    bProgramLoaded: BOOL;
    bTableWriteOk : BOOL;                        (* Rueckmeldung letzter Schreibvorgang *)
    bTableWriteRejected : BOOL;                  (* abgelehnt, z. B. Programm laeuft *)
    nSpeedLimitActivePct : UINT := 25;           (* wirksame Inbetriebnahme-Begrenzung in %, nOvrFeed/nOvrRapid sind bereits damit begrenzt *)
END_STRUCT
END_TYPE
