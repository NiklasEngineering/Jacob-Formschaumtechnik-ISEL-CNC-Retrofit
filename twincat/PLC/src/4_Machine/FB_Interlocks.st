(* Verriegelungsmatrix. Reine Logik ohne Hardwarebezug, daher voll testbar.
   Jede Zeile haengt an einer Anforderung aus der Funktionsliste (Platzhalter-IDs bis Lastenheft da ist). *)
FUNCTION_BLOCK FB_Interlocks
VAR_INPUT
    eMode          : E_OpMode;
    eState         : E_MachState;
    bSafetyOk      : BOOL;
    bAllHomed      : BOOL;
    bDrivesEnabled : BOOL;
    bHmiLinkOk     : BOOL;
    bAnyR2OrHigher : BOOL;
    bAnyR3OrHigher : BOOL;
    bAirOk         : BOOL;
    bHomingBusy    : BOOL;      (* Referenzfahrt laeuft (Befund 8c) *)
    bLimitFreeRun  : BOOL;      (* nur Endschalter-R3 aktiv, Freifahren erlaubt (Befund 15) *)
END_VAR
VAR_OUTPUT
    bProgramStartOk : BOOL;   (* Auto: Start erlaubt *)
    bJogOk          : BOOL;   (* Tippen erlaubt *)
    bHomingOk       : BOOL;
    bSpindleOk      : BOOL;   (* Spindel darf laufen *)
    bAuxOk          : BOOL;   (* Absaugung, Blasluft, Vakuum von Hand *)
    bModeChangeOk   : BOOL;   (* Wechsel nur ohne aktives Programm *)
END_VAR

bProgramStartOk := eMode = E_OpMode.Auto OR eMode = E_OpMode.Setup;
bProgramStartOk := bProgramStartOk AND bSafetyOk AND bDrivesEnabled AND bAllHomed
                   AND NOT bAnyR2OrHigher AND bAirOk AND eState <> E_MachState.Execute AND NOT bHomingBusy;

bJogOk := eMode = E_OpMode.Hand AND bSafetyOk AND bDrivesEnabled AND bHmiLinkOk
          AND (NOT bAnyR3OrHigher OR bLimitFreeRun) AND eState <> E_MachState.Execute AND NOT bHomingBusy;

(* Referenzfahrt nur in Hand und nur im Zustand Idle (nicht in Held/Execute) *)
bHomingOk := eMode = E_OpMode.Hand AND bSafetyOk AND bDrivesEnabled AND NOT bAnyR3OrHigher AND eState = E_MachState.Idle;

bSpindleOk := bSafetyOk AND NOT bAnyR3OrHigher AND eMode <> E_OpMode.Setup;

bAuxOk := bSafetyOk AND eState <> E_MachState.EStop;

bModeChangeOk := eState <> E_MachState.Execute AND eState <> E_MachState.Held;
END_FUNCTION_BLOCK
