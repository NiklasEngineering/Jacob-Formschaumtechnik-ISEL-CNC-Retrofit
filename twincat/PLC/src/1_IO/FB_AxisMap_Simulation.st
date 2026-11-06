(* Simulationsabbild fuer Usermode Runtime ohne Hardware. Folgt der Freigabe verzoegert,
   keine Bewegung. Echte Positionen kommen aus der simulierten CNC-Achse. *)
FUNCTION_BLOCK FB_AxisMap_Simulation
VAR_INPUT
    bSafeEnable : BOOL;
    bHomeReset  : BOOL;     (* Impuls: Referenzstatus loeschen *)
    bHomeCmd    : BOOL;     (* Pegel: Referenzfahrt laeuft *)
END_VAR
VAR_IN_OUT
    stAxis : ST_AxisDrive;
END_VAR
VAR
    tonEnable : TON;
    tonHome   : TON;
END_VAR

tonEnable(IN := stAxis.bEnableReq AND bSafeEnable, PT := T#200MS);
stAxis.bReady        := TRUE;
stAxis.bEnabled      := tonEnable.Q;
stAxis.bFault        := FALSE;
stAxis.nFaultCode    := 0;
stAxis.bHwLimitPlus  := TRUE;
stAxis.bHwLimitMinus := TRUE;

(* Referenzstatus (einzige Quelle, Befund 3): nach 2 s Referenzfahrt gesetzt, bei Reset oder Antriebsfehler geloescht *)
tonHome(IN := bHomeCmd AND stAxis.bEnabled, PT := T#2S);
IF bHomeReset OR stAxis.bFault THEN stAxis.bHomed := FALSE; END_IF
IF tonHome.Q THEN stAxis.bHomed := TRUE; END_IF
END_FUNCTION_BLOCK
