(* Simulationsabbild fuer Usermode Runtime ohne Hardware. Folgt der Freigabe verzoegert,
   keine Bewegung. Echte Positionen kommen aus der simulierten CNC-Achse. *)
FUNCTION_BLOCK FB_AxisMap_Simulation
VAR_INPUT
    bSafeEnable : BOOL;
END_VAR
VAR_IN_OUT
    stAxis : ST_AxisDrive;
END_VAR
VAR
    tonEnable : TON;
END_VAR

tonEnable(IN := stAxis.bEnableReq AND bSafeEnable, PT := T#200MS);
stAxis.bReady        := TRUE;
stAxis.bEnabled      := tonEnable.Q;
stAxis.bFault        := FALSE;
stAxis.nFaultCode    := 0;
stAxis.bHwLimitPlus  := TRUE;
stAxis.bHwLimitMinus := TRUE;
END_FUNCTION_BLOCK
