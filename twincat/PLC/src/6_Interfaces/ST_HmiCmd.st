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
END_STRUCT
END_TYPE
