(* HMI -> SPS. Die HMI fordert nur an. Alle Verriegelungen liegen in der SPS. *)
TYPE ST_HmiCmd :
STRUCT
    nHeartbeat      : UINT;    (* Lebenszeichen, wird von der HMI hochgezaehlt *)
    eModeRequest    : E_OpMode;
    bStart          : BOOL;    (* Impuls *)
    bHold           : BOOL;    (* Impuls, Vorschubhalt *)
    bAbort          : BOOL;    (* Impuls *)
    bAck            : BOOL;    (* Impuls, Meldungen quittieren, Wiederanlauf *)
    bJogPlus        : BOOL;    (* gehalten, nur mit Heartbeat *)
    bJogMinus       : BOOL;
    nJogAxis        : USINT;   (* 1=X, 2=Y, 3=Z *)
    bJogRapid       : BOOL;
    bSpindleOn      : BOOL;    (* nur Hand *)
    bSpindleCcw     : BOOL;
    rSpindleSetRpm  : REAL;    (* 1/min *)
    bExtraction     : BOOL;
    bBlowAir        : BOOL;
    bVacuum         : BOOL;
    bHomeRequest    : BOOL;    (* Impuls *)
    bToolChangeDone : BOOL;    (* Impuls, Quittung manueller Werkzeugwechsel *)
    rJogStepMm      : REAL;    (* 0 = kontinuierlich, sonst 0.01 / 0.1 / 1 / 10 mm *)
    bHandwheelEnable: BOOL;    (* nur M1 mit Bestandsgeraet, [offen] *)
    nHandwheelAxis  : USINT;   (* 1=X, 2=Y, 3=Z *)
    nHandwheelRatio : USINT;   (* 1, 10, 100 *)
    bHomeAxis       : ARRAY[1..3] OF BOOL;   (* Impuls: einzelne Achse referenzieren *)
    bHomeAbort      : BOOL;    (* Impuls *)
    bSingleBlock    : BOOL;    (* Einzelsatz *)
    bDryRun         : BOOL;    (* Trockenlauf: Spindel gesperrt *)
    bOptStop        : BOOL;    (* optionaler Halt M1 *)
END_STRUCT
END_TYPE
