(* Maschinenzustand. Entscheidet aus Sicherheits- und Meldungsklasse, ob Antriebe freigegeben sind
   und wie reagiert wird. Bewegung und Programm laufen in der CNC, hier nur die Anforderungen.
   Befund 4: Bei NOT-HALT/Tuer/Abbruch/R3/R4 aus Execute oder Held bleibt die Abbruch-Anforderung an die CNC
   als Pegel stehen (bAbortPending), bis die CNC meldet, dass kein Programm mehr aktiv ist. Der NOT-HALT-Zustand
   wird erst danach und nach Quittierung verlassen. *)
FUNCTION_BLOCK FB_MachineState
VAR_INPUT
    bSafetyOk       : BOOL;
    bDrivesAllowed  : BOOL;     (* aus FB_SafetyMonitor *)
    bAnyR2OrHigher  : BOOL;
    bAnyR3OrHigher  : BOOL;
    bAnyR4          : BOOL;
    bAckPending     : BOOL;
    bStartOk        : BOOL;     (* aus FB_Interlocks *)
    bStartCmd       : BOOL;     (* Impuls von der HMI *)
    bHoldCmd        : BOOL;
    bAbortCmd       : BOOL;
    bProgramDone    : BOOL;     (* von der CNC, Flanke genuegt *)
    bProgramActive  : BOOL;     (* von der CNC: Programm laeuft oder Achsen fahren noch *)
    bAck            : BOOL;
    tR4OffDelay     : TIME := T#500MS;   (* Befund 15: Reglerfreigabe faellt bei R4 erst, wenn die CNC steht oder nach dieser Zeit *)
END_VAR
VAR_OUTPUT
    eState          : E_MachState;
    bEnableDrives   : BOOL;     (* Reglerfreigabe der SPS *)
    bCncStart       : BOOL;     (* Anforderung an die CNC *)
    bCncHold        : BOOL;
    bCncAbort       : BOOL;     (* Pegel, bis die CNC steht *)
    bSpindleStop    : BOOL;     (* Spindel aus, Pegel bei Abbruch/Fehler/NOT-HALT *)
END_VAR
VAR
    rtStart      : R_TRIG;
    rtHold       : R_TRIG;
    rtAbort      : R_TRIG;
    rtAck        : R_TRIG;
    rtDone       : R_TRIG;
    bAbortPending: BOOL;
    ePrev        : E_MachState;
    tonR4Off     : TON;
END_VAR

rtStart(CLK := bStartCmd);
rtHold(CLK := bHoldCmd);
rtAbort(CLK := bAbortCmd);
rtAck(CLK := bAck);
rtDone(CLK := bProgramDone);
bCncStart := FALSE; bCncHold := FALSE; bSpindleStop := FALSE;
ePrev := eState;

(* Vorrang 1: Sicherheitskreis offen -> NOT-HALT-Zustand, Antriebe aus, Programm abbrechen *)
IF NOT bSafetyOk THEN
    IF eState = E_MachState.Execute OR eState = E_MachState.Held THEN
        bAbortPending := TRUE;
    END_IF
    eState := E_MachState.EStop;
ELSIF eState = E_MachState.EStop THEN
    (* Sicherheitskreis wieder zu: Quittierung, Programm muss beendet sein *)
    IF bDrivesAllowed AND rtAck.Q AND NOT bAbortPending THEN eState := E_MachState.Stopped; END_IF
END_IF

(* Vorrang 2: Meldungsklassen *)
IF eState <> E_MachState.EStop THEN
    IF bAnyR4 THEN
        IF eState = E_MachState.Execute OR eState = E_MachState.Held THEN bAbortPending := TRUE; END_IF
        eState := E_MachState.Fault;
    ELSIF bAnyR3OrHigher THEN
        IF eState = E_MachState.Execute OR eState = E_MachState.Held THEN
            bAbortPending := TRUE;
        END_IF
        eState := E_MachState.Aborted;
    ELSIF bAnyR2OrHigher AND eState = E_MachState.Execute THEN
        bCncHold := TRUE;
        eState := E_MachState.Held;
    END_IF
END_IF

(* Normaler Ablauf *)
CASE eState OF
    E_MachState.Stopped:
        IF bDrivesAllowed AND NOT bAnyR3OrHigher AND NOT bAckPending THEN
            eState := E_MachState.Idle;
        END_IF
    E_MachState.Idle:
        IF rtStart.Q AND bStartOk THEN
            bCncStart := TRUE;
            eState := E_MachState.Execute;
        END_IF
    E_MachState.Execute:
        IF rtHold.Q THEN bCncHold := TRUE; eState := E_MachState.Held; END_IF
        IF rtAbort.Q THEN bAbortPending := TRUE; eState := E_MachState.Aborted; END_IF
        IF rtDone.Q THEN eState := E_MachState.Idle; END_IF
    E_MachState.Held:
        IF rtStart.Q AND bStartOk AND NOT bAnyR2OrHigher THEN
            bCncStart := TRUE; eState := E_MachState.Execute;
        END_IF
        IF rtAbort.Q THEN bAbortPending := TRUE; eState := E_MachState.Aborted; END_IF
    E_MachState.Aborted, E_MachState.Fault:
        IF rtAck.Q AND NOT bAnyR3OrHigher AND NOT bAckPending AND NOT bAbortPending THEN eState := E_MachState.Stopped; END_IF
END_CASE

(* Abbruch bleibt angefordert, bis die CNC steht *)
IF bAbortPending AND NOT bProgramActive AND ePrev = eState AND NOT (rtAbort.Q) THEN
    bAbortPending := FALSE;
END_IF
bCncAbort := bAbortPending;

(* Spindel aus in allen Zustaenden ausser Idle/Execute/Held/Stopped *)
bSpindleStop := bAbortPending OR eState = E_MachState.EStop OR eState = E_MachState.Aborted OR eState = E_MachState.Fault;

(* Befund 15: Bei R4 (Zustand Fault) bremst die CNC gefuehrt (Abbruch laeuft), die Freigabe faellt, sobald
   die CNC kein Programm/keine Bewegung mehr meldet, spaetestens nach tR4OffDelay. NOT-HALT wirkt sofort
   (Sicherheitsrelais nimmt die Freigabe in Hardware, bDrivesAllowed faellt im selben Zyklus). *)
tonR4Off(IN := bAnyR4 OR eState = E_MachState.Fault, PT := tR4OffDelay);
bEnableDrives := bDrivesAllowed AND eState <> E_MachState.EStop
                 AND NOT ((bAnyR4 OR eState = E_MachState.Fault) AND (tonR4Off.Q OR NOT bProgramActive));
END_FUNCTION_BLOCK
