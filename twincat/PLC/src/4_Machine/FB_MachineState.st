(* Maschinenzustand. Entscheidet aus Sicherheits- und Meldungsklasse, ob Antriebe freigegeben sind
   und wie reagiert wird. Bewegung und Programm laufen in der CNC, hier nur die Anforderungen. *)
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
    bProgramDone    : BOOL;     (* von der CNC *)
    bAck            : BOOL;
END_VAR
VAR_OUTPUT
    eState          : E_MachState;
    bEnableDrives   : BOOL;     (* Reglerfreigabe der SPS *)
    bCncStart       : BOOL;     (* Anforderung an die CNC *)
    bCncHold        : BOOL;
    bCncAbort       : BOOL;
    bSpindleStop    : BOOL;     (* Spindel sofort aus *)
END_VAR
VAR
    rtStart : R_TRIG;
    rtHold  : R_TRIG;
    rtAbort : R_TRIG;
    rtAck   : R_TRIG;
END_VAR

rtStart(CLK := bStartCmd);
rtHold(CLK := bHoldCmd);
rtAbort(CLK := bAbortCmd);
rtAck(CLK := bAck);
bCncStart := FALSE; bCncHold := FALSE; bCncAbort := FALSE; bSpindleStop := FALSE;

(* Vorrang 1: Sicherheitskreis offen -> NOT-HALT-Zustand, Antriebe aus *)
IF NOT bSafetyOk THEN
    eState := E_MachState.EStop;
ELSIF eState = E_MachState.EStop THEN
    (* Sicherheitskreis wieder zu: erst Quittierung, dann Fault/Aborted/Stopped *)
    IF bDrivesAllowed AND rtAck.Q THEN eState := E_MachState.Stopped; END_IF
END_IF

(* Vorrang 2: Meldungsklassen *)
IF eState <> E_MachState.EStop THEN
    IF bAnyR4 THEN
        eState := E_MachState.Fault;
        bCncAbort := TRUE; bSpindleStop := TRUE;
    ELSIF bAnyR3OrHigher THEN
        IF eState = E_MachState.Execute OR eState = E_MachState.Held THEN
            bCncAbort := TRUE;
        END_IF
        bSpindleStop := TRUE;
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
        IF rtAbort.Q THEN bCncAbort := TRUE; bSpindleStop := TRUE; eState := E_MachState.Aborted; END_IF
        IF bProgramDone THEN eState := E_MachState.Idle; END_IF
    E_MachState.Held:
        IF rtStart.Q AND bStartOk AND NOT bAnyR2OrHigher THEN
            bCncStart := TRUE; eState := E_MachState.Execute;
        END_IF
        IF rtAbort.Q THEN bCncAbort := TRUE; bSpindleStop := TRUE; eState := E_MachState.Aborted; END_IF
    E_MachState.Aborted, E_MachState.Fault:
        IF rtAck.Q AND NOT bAnyR3OrHigher AND NOT bAckPending THEN eState := E_MachState.Stopped; END_IF
END_CASE

bEnableDrives := bDrivesAllowed AND NOT bAnyR4 AND eState <> E_MachState.EStop AND eState <> E_MachState.Fault;
END_FUNCTION_BLOCK
