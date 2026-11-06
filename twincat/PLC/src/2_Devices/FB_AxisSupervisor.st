(* Ueberwacht vier Achsen (Index 1..4) und fasst Zustaende fuer die Meldeliste zusammen.
   Muss-Anforderungen: 2.2.3 Hardware-Endschalter, 2.2.6 Referenzverlust, 2.10.4 Ueberwachung
   von Feldbus und Antrieben. Endschalter im Ruhestrom (FALSE = ausgeloest). *)
FUNCTION_BLOCK FB_AxisSupervisor
VAR_INPUT
    bEnableCmd      : BOOL;     (* Reglerfreigabe angefordert *)
    bFieldbusOk     : BOOL;
    bHomingActive   : BOOL;     (* gewollte Referenzfahrt laeuft: kein Referenzverlust (Befund 5) *)
    rMaxFollowErr   : LREAL;    (* mm, [Annahme] bis Achsdaten vorliegen *)
END_VAR
VAR_IN_OUT
    aAxis : ARRAY[1..4] OF ST_AxisDrive;
END_VAR
VAR_OUTPUT
    bAnyFault      : BOOL;
    bAnyHwLimit    : BOOL;
    bFollowErr     : BOOL;
    bAllReady      : BOOL;
    bAllEnabled    : BOOL;
    bAllHomed      : BOOL;
    bHomingLost    : BOOL;      (* Referenz war da und ist weg (Regler aus/Fehler) *)
    bEnableTimeout : BOOL;      (* Freigabe angefordert, aber Antriebe melden nicht freigegeben (Befund 14) *)
END_VAR
VAR
    i           : INT;
    bHadHomed   : BOOL;
    tonEnable   : TON;
END_VAR

bAnyFault := FALSE; bAnyHwLimit := FALSE; bFollowErr := FALSE;
bAllReady := TRUE; bAllEnabled := TRUE; bAllHomed := TRUE;

FOR i := 1 TO 4 DO
    IF aAxis[i].bFault THEN bAnyFault := TRUE; END_IF
    IF NOT aAxis[i].bHwLimitPlus OR NOT aAxis[i].bHwLimitMinus THEN bAnyHwLimit := TRUE; END_IF
    IF ABS(aAxis[i].rFollowErr) > rMaxFollowErr THEN bFollowErr := TRUE; END_IF
    IF NOT aAxis[i].bReady   THEN bAllReady := FALSE; END_IF
    IF NOT aAxis[i].bEnabled THEN bAllEnabled := FALSE; END_IF
    IF NOT aAxis[i].bHomed   THEN bAllHomed := FALSE; END_IF
END_FOR

(* Referenzverlust: war referenziert und ist es nicht mehr *)
IF bAllHomed THEN
    bHadHomed := TRUE;
    bHomingLost := FALSE;
ELSIF bHomingActive THEN
    bHadHomed := FALSE;
    bHomingLost := FALSE;
ELSIF bHadHomed THEN
    bHomingLost := TRUE;
    bHadHomed := FALSE;
END_IF
IF NOT bFieldbusOk THEN
    bAllReady := FALSE; bAllEnabled := FALSE;
END_IF

tonEnable(IN := bEnableCmd AND bFieldbusOk AND NOT bAllEnabled, PT := T#3S);
bEnableTimeout := tonEnable.Q;
END_FUNCTION_BLOCK
