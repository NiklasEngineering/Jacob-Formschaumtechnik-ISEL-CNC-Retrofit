(* Referenzfahrt als Ablauf: Z zuerst (Spindel nach oben), dann Querachse, dann Portal (Gantry).
   Reihenfolge und Richtung einstellbar (Anforderung 2.2.1). Der Baustein fordert die Fahrt an,
   die Bewegung selbst macht die CNC bzw. der Antrieb. Gantry-Ausrichtung beider Portalseiten
   gehoert in die CNC-Parametrierung. Gruppen: 1 = Z, 2 = X (Quer), 3 = Y (Portal).
   [Annahme] Reihenfolge Z, X, Y, bis Maschinenaufbau bestaetigt.
   Befund 8: Je Gruppe ein Handshake. Erst kommt ein Ruecksetz-Impuls (aResetHomed), dann muss aHomed
   FALSE werden, danach steht bHomeCmd als Pegel, bis aHomed wieder TRUE ist. Zwischen zwei Gruppen
   faellt bHomeCmd mindestens einen Zyklus. Einzelne X/Y-Referenzfahrt nur mit referenziertem Z. *)
FUNCTION_BLOCK FB_Homing
VAR_INPUT
    bStart       : BOOL;                      (* Impuls: alle Achsen in Reihenfolge *)
    aStartAxis   : ARRAY[1..3] OF BOOL;       (* Impuls: nur diese Gruppe *)
    bAbort       : BOOL;
    bHomingOk    : BOOL;
    aHomed       : ARRAY[1..3] OF BOOL;       (* je Gruppe, aus dem einheitlichen Referenzstatus *)
    aOrder       : ARRAY[1..3] OF USINT := [1, 2, 3];
    tTimeout     : TIME := T#120S;
END_VAR
VAR_OUTPUT
    bBusy        : BOOL;
    bDone        : BOOL;
    bError       : BOOL;
    nActiveGroup : USINT;                     (* Gruppe, die gerade referenziert wird, 0 = keine *)
    bHomeCmd     : BOOL;                      (* Anforderung an die CNC/den Antrieb fuer nActiveGroup *)
    aResetHomed  : ARRAY[1..3] OF BOOL;       (* Impuls: Referenzstatus dieser Gruppe loeschen *)
    eHomeState   : ARRAY[1..3] OF E_HomeState;
    nStepOut     : USINT;
END_VAR
VAR
    nStep      : INT;
    nSub       : INT;                         (* 0 Reset senden, 1 auf Reset warten, 2 fahren *)
    nSingle    : USINT;
    rtStart    : R_TRIG;
    rtSingle   : ARRAY[1..3] OF R_TRIG;
    tonTimeout : TON;
    i          : INT;
END_VAR

rtStart(CLK := bStart);
FOR i := 1 TO 3 DO
    rtSingle[i](CLK := aStartAxis[i]);
    aResetHomed[i] := FALSE;
END_FOR
bHomeCmd := FALSE;

IF bAbort OR (bBusy AND NOT bHomingOk) THEN
    IF bBusy AND nActiveGroup > 0 THEN eHomeState[nActiveGroup] := E_HomeState.Open; END_IF
    nStep := 0; nSub := 0; bBusy := FALSE; nActiveGroup := 0; tonTimeout(IN := FALSE);
END_IF

CASE nStep OF
    0:
        IF bHomingOk THEN
            IF rtStart.Q THEN
                bDone := FALSE; bError := FALSE; bBusy := TRUE; nSingle := 0; nStep := 1; nSub := 0;
                FOR i := 1 TO 3 DO eHomeState[i] := E_HomeState.Open; END_FOR
            ELSE
                FOR i := 1 TO 3 DO
                    IF rtSingle[i].Q AND NOT bBusy THEN
                        IF i > 1 AND NOT aHomed[1] THEN
                            bError := TRUE;    (* Z muss zuerst referenziert sein *)
                        ELSE
                            bDone := FALSE; bError := FALSE; bBusy := TRUE; nSingle := TO_USINT(i);
                            nStep := 1; nSub := 0;
                            eHomeState[i] := E_HomeState.Open;
                        END_IF
                    END_IF
                END_FOR
            END_IF
        END_IF
    1, 2, 3:
        IF nSingle > 0 THEN
            nActiveGroup := nSingle;
        ELSE
            nActiveGroup := aOrder[nStep];
        END_IF
        tonTimeout(IN := TRUE, PT := tTimeout);
        CASE nSub OF
            0:  aResetHomed[nActiveGroup] := TRUE;
                eHomeState[nActiveGroup] := E_HomeState.Running;
                nSub := 1;
            1:  IF NOT aHomed[nActiveGroup] THEN nSub := 2; END_IF
            2:  bHomeCmd := TRUE;
                IF aHomed[nActiveGroup] THEN
                    eHomeState[nActiveGroup] := E_HomeState.Done;
                    tonTimeout(IN := FALSE);
                    nSub := 0;
                    IF nSingle > 0 THEN nStep := 4; ELSE nStep := nStep + 1; END_IF
                END_IF
        END_CASE
        IF tonTimeout.Q THEN
            eHomeState[nActiveGroup] := E_HomeState.Error;
            bError := TRUE; bBusy := FALSE; nActiveGroup := 0; nStep := 0; nSub := 0;
            tonTimeout(IN := FALSE);
        END_IF
    4:
        bDone := TRUE; bBusy := FALSE; nActiveGroup := 0; nStep := 0; nSub := 0;
END_CASE
nStepOut := TO_USINT(nStep);
END_FUNCTION_BLOCK
