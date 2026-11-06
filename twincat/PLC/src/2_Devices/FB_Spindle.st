(* Spindel isel VKH63/26-90T, 2,2 kW, max. 16600 1/min, am FU Emerson Commander SK.
   Ansteuerung Variante 1: Start/Richtung digital, Drehzahl 0..10 V. Variante Modbus RTU ist offen.
   [Annahme] Start und Richtung als getrennte Ausgaenge, FU-Rueckmeldung "bereit" und "Drehzahl erreicht"
   als Eingaenge. Bis Schaltplan vorliegt, ist das nicht belegt.
   Befund 1 der Papierpruefung: Die Anforderung ist selbsthaltend. Ein Start entsteht nur aus einer
   steigenden Flanke von bStartCw/bStartCcw. Jeder Stopp (Release weg, Fehler, bStop, Einrichten)
   loescht die Anforderung. Ein noch anstehender Pegel startet die Spindel nie von selbst neu.
   Befund 13: Drehrichtungsumkehr nur ueber Stillstand (Auslaufzeit). *)
FUNCTION_BLOCK FB_Spindle
VAR_INPUT
    bRelease      : BOOL;        (* Betriebsart + Sicherheit erlauben die Spindel *)
    bSetupLocked  : BOOL;        (* Betriebsart Einrichten/Test: Spindel gesperrt *)
    bStop         : BOOL;        (* Stopp-Anforderung (Abbruch, R3/R4, NOT-HALT): loescht die Anforderung *)
    bStartCw      : BOOL;        (* M3 bzw. Hand-Taste, Pegel *)
    bStartCcw     : BOOL;        (* M4 bzw. Hand-Taste, Pegel *)
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
    rtCw       : R_TRIG;
    rtCcw      : R_TRIG;
    nDirAct    : INT;            (* 0 = keine Anforderung, 1 = rechts, 2 = links *)
    nDirPend   : INT;            (* wartet auf Stillstand, 0 = nichts *)
    bStopCond  : BOOL;
END_VAR

rtAck(CLK := bAckReset);
rtCw(CLK := bStartCw);
rtCcw(CLK := bStartCcw);

bPtcTrip := NOT bPtcOk;
bFault   := NOT bFuReady OR bPtcTrip;
IF bFault THEN bLatchFault := TRUE; END_IF
IF bLatchFault AND rtAck.Q AND bFuReady AND bPtcOk THEN bLatchFault := FALSE; END_IF

bLockedSetup := bSetupLocked AND (bStartCw OR bStartCcw);

(* Anforderung verwalten *)
bStopCond := bStop OR NOT bRelease OR bSetupLocked OR bLatchFault;
IF bStopCond THEN
    nDirAct := 0; nDirPend := 0;
ELSE
    (* Ende der Anforderung: M5 bzw. Taste aus *)
    IF NOT bStartCw  AND nDirAct = 1 THEN nDirAct := 0; END_IF
    IF NOT bStartCcw AND nDirAct = 2 THEN nDirAct := 0; END_IF
    IF NOT bStartCw  AND nDirPend = 1 THEN nDirPend := 0; END_IF
    IF NOT bStartCcw AND nDirPend = 2 THEN nDirPend := 0; END_IF
    (* neuer Start nur mit steigender Flanke *)
    IF rtCw.Q  AND bStartCw  AND NOT bStartCcw THEN nDirPend := 1; END_IF
    IF rtCcw.Q AND bStartCcw AND NOT bStartCw  THEN nDirPend := 2; END_IF
    (* Start erst, wenn die Spindel steht (auch bei Richtungsumkehr) *)
    IF nDirPend <> 0 AND nDirAct = 0 AND bStandstillOk THEN
        nDirAct := nDirPend; nDirPend := 0;
    END_IF
END_IF

bWantRun := nDirAct <> 0;
bRunCmd  := bWantRun;
bDirCcw  := nDirAct = 2;

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
