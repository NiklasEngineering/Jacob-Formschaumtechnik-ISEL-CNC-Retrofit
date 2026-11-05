(* Zustandsgroessen und CNC-Schnittstelle (Signale aus/zur CNC kommen spaeter ueber Tc2_CncHli). *)
VAR_GLOBAL
    stParams       : ST_MachineParams;
    bParamsLoaded  : BOOL;
    (* von der CNC [offen, HLI-Anbindung folgt] *)
    nCncMCode      : INT;
    bCncMStrobe    : BOOL;
    nCncToolNo     : UINT;
    bCncProgramDone: BOOL;
    aCncHomed      : ARRAY[1..3] OF BOOL;
    (* zur CNC *)
    bCncStartReq   : BOOL;
    bCncHoldReq    : BOOL;
    bCncAbortReq   : BOOL;
    bCncMAck       : BOOL;
    bCncJogPlus    : BOOL;
    bCncJogMinus   : BOOL;
    nCncJogAxis    : USINT;
    bCncJogRapid   : BOOL;
    bCncHomeReq    : BOOL;
    nCncHomeGroup  : USINT;
    bCncSingleBlock: BOOL;
    bCncDryRun     : BOOL;
    bCncOptStop    : BOOL;
    rCncJogStepMm  : REAL;
    bCncHandwheel  : BOOL;
    nCncHandwheelAxis  : USINT;
    nCncHandwheelRatio : USINT;
    bHasHandwheel  : BOOL;     (* [offen] nur M1 mit Bestandsgeraet *)
END_VAR
