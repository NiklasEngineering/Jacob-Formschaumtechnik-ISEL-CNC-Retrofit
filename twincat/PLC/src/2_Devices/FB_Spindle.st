(* Spindel isel VKH63/26-90T, 2,2 kW, max. 16600 1/min, am FU Emerson Commander SK.
   Ansteuerung Variante 1: Start/Richtung digital, Drehzahl 0..10 V. Variante Modbus RTU ist offen.
   [Annahme] Start und Richtung als getrennte Ausgaenge, FU-Rueckmeldung "bereit" und "Drehzahl erreicht"
   als Eingaenge. Bis Schaltplan vorliegt, ist das nicht belegt. *)
FUNCTION_BLOCK FB_Spindle
VAR_INPUT
    bRelease      : BOOL;        (* Betriebsart + Sicherheit erlauben die Spindel *)
    bSetupLocked  : BOOL;        (* Betriebsart Einrichten/Test: Spindel gesperrt *)
    bStartCw      : BOOL;        (* M3 *)
    bStartCcw     : BOOL;        (* M4 *)
    rSetRpm       : REAL;        (* S-Wert, 1/min *)
    rOverridePct  : REAL;        (* 0..150 *)
    bFuReady      : BOOL;        (* FU bereit, Ruhestrom: FALSE = Stoerung *)
    bFuAtSpeed    : BOOL;        (* [Annahme] FU meldet Drehzahl erreicht *)
    bPtcOk        : BOOL;        (* Kaltleiter Motor, Ruhestrom: FALSE = Uebertemperatur *)
    bAckReset     : BOOL;
    rMaxRpm       : REAL;
    rMinRpm       : REAL;
    rVoltMax      : REAL;
    tRunUp        : TIME;
    tStandstill   : TIME;
END_VAR
VAR_OUTPUT
    bRunCmd       : BOOL;        (* Ausgang Start *)
    bDirCcw       : BOOL;        (* Ausgang Richtung *)
    rVoltOut      : REAL;        (* Ausgang 0..10 V (EL4002) *)
    bRunning      : BOOL;        (* Drehzahl erreicht *)
    bStandstillOk : BOOL;        (* Spindel steht (Auslaufzeit abgelaufen) *)
    bFault        : BOOL;
    bPtcTrip      : BOOL;
    bNoFeedback   : BOOL;
    bLockedSetup  : BOOL;        (* Start versucht, aber gesperrt *)
    rActRpm       : REAL;        (* berechneter Sollwert nach Override; kein Istwert! *)
END_VAR
VAR
    tonRunUp   : TON;
    tonStop    : TON;
    rRpm       : REAL;
    bWantRun   : BOOL;
    bLatchFault: BOOL;
    rtAck      : R_TRIG;
END_VAR

rtAck(CLK := bAckReset);

bPtcTrip := NOT bPtcOk;
bFault   := NOT bFuReady OR bPtcTrip;
IF bFault THEN bLatchFault := TRUE; END_IF
IF bLatchFault AND rtAck.Q AND bFuReady AND bPtcOk THEN bLatchFault := FALSE; END_IF

bLockedSetup := bSetupLocked AND (bStartCw OR bStartCcw);
bWantRun := (bStartCw XOR bStartCcw) AND bRelease AND NOT bSetupLocked AND NOT bLatchFault;

bRunCmd := bWantRun;
bDirCcw := bWantRun AND bStartCcw;

(* Drehzahl begrenzen und Override anwenden *)
rRpm := rSetRpm * LIMIT(0.0, rOverridePct, 150.0) / 100.0;
rRpm := LIMIT(rMinRpm, rRpm, rMaxRpm);
IF bWantRun AND rMaxRpm > 0.0 THEN
    rVoltOut := rRpm / rMaxRpm * rVoltMax;
    rActRpm  := rRpm;
ELSE
    rVoltOut := 0.0;
    rActRpm  := 0.0;
END_IF

(* Rueckmeldung: nach Hochlaufzeit muss FU "Drehzahl erreicht" melden *)
tonRunUp(IN := bWantRun, PT := tRunUp);
bRunning    := bWantRun AND bFuAtSpeed;
bNoFeedback := tonRunUp.Q AND NOT bFuAtSpeed;

(* Auslaufzeit: Stillstand gilt erst nach Ablauf *)
tonStop(IN := NOT bWantRun, PT := tStandstill);
bStandstillOk := tonStop.Q;
END_FUNCTION_BLOCK
