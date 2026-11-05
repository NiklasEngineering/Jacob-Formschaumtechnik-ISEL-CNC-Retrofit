(* Referenzfahrt als Ablauf: Z zuerst (Spindel nach oben), dann Querachse, dann Portal (Gantry).
   Reihenfolge und Richtung einstellbar (Anforderung 2.2.1). Der Baustein fordert die Fahrt an,
   die Bewegung selbst macht die CNC bzw. der Antrieb. Gantry-Ausrichtung beider Portalseiten
   gehoert in die CNC-Parametrierung. Gruppen: 1 = Z, 2 = X (Quer), 3 = Y (Portal).
   [Annahme] Reihenfolge Z, X, Y, bis Maschinenaufbau bestaetigt. *)
FUNCTION_BLOCK FB_Homing
VAR_INPUT
    bStart       : BOOL;                      (* Impuls: alle Achsen in Reihenfolge *)
    aStartAxis   : ARRAY[1..3] OF BOOL;       (* Impuls: nur diese Gruppe *)
    bAbort       : BOOL;
    bHomingOk    : BOOL;
    aHomed       : ARRAY[1..3] OF BOOL;       (* von der CNC je Gruppe *)
    aOrder       : ARRAY[1..3] OF USINT := [1, 2, 3];
    tTimeout     : TIME := T#120S;
END_VAR
VAR_OUTPUT
    bBusy        : BOOL;
    bDone        : BOOL;
    bError       : BOOL;
    nActiveGroup : USINT;                     (* Gruppe, die gerade referenziert wird, 0 = keine *)
    bHomeCmd     : BOOL;                      (* Anforderung an die CNC fuer nActiveGroup *)
    eHomeState   : ARRAY[1..3] OF E_HomeState;
    nStepOut     : USINT;
END_VAR
VAR
    nStep      : INT;
    nLast      : INT;                         (* letzter Schritt, 3 = alle, 1 = einzeln *)
    nSingle    : USINT;
    rtStart    : R_TRIG;
    rtSingle   : ARRAY[1..3] OF R_TRIG;
    tonTimeout : TON;
    i          : INT;
END_VAR

rtStart(CLK := bStart);
FOR i := 1 TO 3 DO
    rtSingle[i](CLK := aStartAxis[i]);
END_FOR
bHomeCmd := FALSE;

IF bAbort OR (bBusy AND NOT bHomingOk) THEN
    IF bBusy AND nActiveGroup > 0 THEN eHomeState[nActiveGroup] := E_HomeState.Open; END_IF
    nStep := 0; bBusy := FALSE; nActiveGroup := 0; tonTimeout(IN := FALSE);
END_IF

CASE nStep OF
    0:
        IF bHomingOk THEN
            IF rtStart.Q THEN
                bDone := FALSE; bError := FALSE; bBusy := TRUE; nSingle := 0; nStep := 1;
            ELSE
                FOR i := 1 TO 3 DO
                    IF rtSingle[i].Q THEN
                        bDone := FALSE; bError := FALSE; bBusy := TRUE; nSingle := TO_USINT(i); nStep := 1;
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
        bHomeCmd := TRUE;
        eHomeState[nActiveGroup] := E_HomeState.Running;
        tonTimeout(IN := TRUE, PT := tTimeout);
        IF aHomed[nActiveGroup] THEN
            eHomeState[nActiveGroup] := E_HomeState.Done;
            tonTimeout(IN := FALSE);
            IF nSingle > 0 THEN nStep := 4; ELSE nStep := nStep + 1; END_IF
        ELSIF tonTimeout.Q THEN
            eHomeState[nActiveGroup] := E_HomeState.Error;
            bError := TRUE; bBusy := FALSE; nActiveGroup := 0; nStep := 0;
            tonTimeout(IN := FALSE);
        END_IF
    4:
        bDone := TRUE; bBusy := FALSE; nActiveGroup := 0; nStep := 0;
END_CASE
nStepOut := TO_USINT(nStep);
END_FUNCTION_BLOCK
