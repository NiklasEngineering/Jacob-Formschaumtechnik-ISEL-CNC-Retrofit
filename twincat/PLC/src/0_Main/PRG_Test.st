(* Simulationstest der Grundfunktionen (nur im Simulations-Build, GVL_Config.bSimulationBuild).
   Starten: bTestEnable online auf TRUE setzen. Der Test speist Eingaenge und HMI-Kommandos ein und prueft
   Referenz, Tippen, NOT-HALT und Spindel gegen die Fehlerfaelle aus dem Gutachten (kein Selbstanlauf nach
   Quittierung). Ergebnis: bTestDone, nFails, sFirstFail. Rueckgabe in der Runtime lesen. *)
PROGRAM PRG_Test
VAR
    bTestEnable : BOOL;                 (* online auf TRUE setzen *)
    bTestDone   : BOOL;
    nFails      : INT;
    sFirstFail  : STRING(100);
    nStep       : INT;
    tWait       : TIME;
    tonStep     : TON;
    tonHb       : TON;
    bNext       : BOOL;
    bRelay      : BOOL := TRUE;         (* Rueckmeldung Sicherheitsrelais, NOT-HALT = FALSE *)
    bFailNow    : BOOL;
    sMsg        : STRING(100);
END_VAR

IF NOT (bTestEnable AND GVL_Config.bSimulationBuild) THEN
    nStep := 0;
    RETURN;
END_IF

(* Simulierte HMI: Lebenszeichen alle 100 ms. Simulierter Umrichter: Drehzahl erreicht folgt dem Start. *)
tonHb(IN := NOT tonHb.Q, PT := T#100MS);
IF tonHb.Q THEN GVL_HMI.stCmd.nHeartbeat := GVL_HMI.stCmd.nHeartbeat + 1; END_IF
GVL_IO.bFuAtSpeed := GVL_IO.bSpindleRun;

(* Simulierte Eingaenge: alles in Ordnung, nur das Sicherheitsrelais steuert der Test *)
GVL_IO.bSafetyRelayFeedback := bRelay;
GVL_IO.bDoorClosed   := TRUE;
GVL_IO.bAirOk        := TRUE;
GVL_IO.bExtractionOk := TRUE;
GVL_IO.bFuReady      := TRUE;
GVL_IO.bSpindlePtcOk := TRUE;
GVL_IO.bFieldbusOk   := TRUE;

tonStep(IN := NOT bNext, PT := tWait);
bNext := FALSE;

CASE nStep OF
    0:  (* Start *)
        nFails := 0; sFirstFail := ''; bTestDone := FALSE; bRelay := TRUE;
        GVL_HMI.stCmd.eModeRequest := E_OpMode.Hand;
        nStep := 10; tWait := T#1S; bNext := TRUE;

    10: (* T01 Anlauf: Maschine startet gelatcht, nicht frei *)
        IF tonStep.Q THEN
            IF GVL_HMI.stSts.eState <> E_MachState.Stopped THEN sMsg := 'T01 Anlauf nicht gelatcht (Zustand nicht Stopped)'; bFailNow := TRUE; END_IF
            GVL_HMI.stCmd.bAck := TRUE;
            nStep := 20; tWait := T#1S; bNext := TRUE;
        END_IF

    20: (* T02 Quittierung -> Idle, dann Referenzfahrt anfordern *)
        IF tonStep.Q THEN
            IF GVL_HMI.stSts.eState <> E_MachState.Idle THEN sMsg := 'T02 Quittierung fuehrt nicht nach Idle'; bFailNow := TRUE; END_IF
            GVL_HMI.stCmd.bHomeRequest := TRUE;
            nStep := 30; tWait := T#20S; bNext := TRUE;
        END_IF

    30: (* T03 Referenzfahrt aller Gruppen *)
        IF GVL_HMI.stSts.bAllHomed THEN
            nStep := 40; tWait := T#500MS; bNext := TRUE;
        ELSIF tonStep.Q THEN
            sMsg := 'T03 Referenzfahrt: Zeitueberschreitung'; bFailNow := TRUE;
            nStep := 40; tWait := T#500MS; bNext := TRUE;
        END_IF

    40: (* Tippen: Achse waehlen, 300 ms stabil *)
        IF tonStep.Q THEN
            GVL_HMI.stCmd.nJogAxis := 1;
            nStep := 50; tWait := T#300MS; bNext := TRUE;
        END_IF

    50: (* Tippen+ starten *)
        IF tonStep.Q THEN
            GVL_HMI.stCmd.bJogPlus := TRUE;
            nStep := 60; tWait := T#500MS; bNext := TRUE;
        END_IF

    60: (* T04 Tippen+ aktiv, dann loslassen *)
        IF tonStep.Q THEN
            IF NOT GVL_Machine.bCncJogPlus THEN sMsg := 'T04 Tippen+ startet nicht'; bFailNow := TRUE; END_IF
            GVL_HMI.stCmd.bJogPlus := FALSE;
            nStep := 70; tWait := T#300MS; bNext := TRUE;
        END_IF

    70: (* T05 Tippen stoppt beim Loslassen, dann Taste wieder druecken *)
        IF tonStep.Q THEN
            IF GVL_Machine.bCncJogPlus THEN sMsg := 'T05 Tippen stoppt nicht beim Loslassen'; bFailNow := TRUE; END_IF
            GVL_HMI.stCmd.bJogPlus := TRUE;
            nStep := 80; tWait := T#400MS; bNext := TRUE;
        END_IF

    80: (* NOT-HALT bei gehaltener Tippen-Taste *)
        IF tonStep.Q THEN
            bRelay := FALSE;
            nStep := 90; tWait := T#500MS; bNext := TRUE;
        END_IF

    90: (* T07 NOT-HALT erkannt, Tippen aus, Antriebe weg *)
        IF tonStep.Q THEN
            IF GVL_HMI.stSts.eState <> E_MachState.EStop THEN sMsg := 'T07 NOT-HALT nicht erkannt'; bFailNow := TRUE; END_IF
            IF GVL_Machine.bCncJogPlus THEN sMsg := 'T07b Tippen laeuft bei NOT-HALT weiter'; bFailNow := TRUE; END_IF
            IF GVL_HMI.stSts.bDrivesEnabled THEN sMsg := 'T07c Antriebe bleiben bei NOT-HALT frei'; bFailNow := TRUE; END_IF
            bRelay := TRUE;
            nStep := 100; tWait := T#500MS; bNext := TRUE;
        END_IF

    100: (* T08/T06 Sicherheitskreis wieder zu: kein Wiederanlauf, gehaltene Taste startet nichts *)
        IF tonStep.Q THEN
            IF GVL_HMI.stSts.eState <> E_MachState.EStop THEN sMsg := 'T08 NOT-HALT ohne Quittierung verlassen'; bFailNow := TRUE; END_IF
            IF GVL_Machine.bCncJogPlus THEN sMsg := 'T06 Tippen startet nach NOT-HALT von selbst'; bFailNow := TRUE; END_IF
            GVL_HMI.stCmd.bAck := TRUE;
            nStep := 110; tWait := T#1500MS; bNext := TRUE;
        END_IF

    110: (* T09 Quittierung -> Idle, gehaltene Tippen-Taste startet nicht, dann Spindel in Hand *)
        IF tonStep.Q THEN
            IF GVL_HMI.stSts.eState <> E_MachState.Idle THEN sMsg := 'T09 Quittierung nach NOT-HALT fuehrt nicht nach Idle'; bFailNow := TRUE; END_IF
            IF GVL_Machine.bCncJogPlus THEN sMsg := 'T06b Tippen startet nach Quittierung von selbst'; bFailNow := TRUE; END_IF
            GVL_HMI.stCmd.bJogPlus := FALSE;
            GVL_HMI.stCmd.rSpindleSetRpm := 12000.0;
            GVL_HMI.stCmd.bSpindleOn := TRUE;
            nStep := 120; tWait := T#1500MS; bNext := TRUE;
        END_IF

    120: (* T10 Spindel startet in Hand, Spannung passt zur Drehzahl *)
        IF tonStep.Q THEN
            IF NOT GVL_IO.bSpindleRun THEN sMsg := 'T10 Spindel startet nicht (Hand)'; bFailNow := TRUE; END_IF
            IF ABS(GVL_IO.rSpindleVolt - 7.2) > 0.3 THEN sMsg := 'T10b Spindelspannung passt nicht zu 12000 1/min'; bFailNow := TRUE; END_IF
            bRelay := FALSE;
            nStep := 130; tWait := T#400MS; bNext := TRUE;
        END_IF

    130: (* T11 Spindel stoppt bei NOT-HALT *)
        IF tonStep.Q THEN
            IF GVL_IO.bSpindleRun THEN sMsg := 'T11 Spindel laeuft bei NOT-HALT weiter'; bFailNow := TRUE; END_IF
            bRelay := TRUE;
            nStep := 140; tWait := T#500MS; bNext := TRUE;
        END_IF

    140: (* Quittieren, Spindeltaste bleibt gedrueckt *)
        IF tonStep.Q THEN
            GVL_HMI.stCmd.bAck := TRUE;
            nStep := 150; tWait := T#1500MS; bNext := TRUE;
        END_IF

    150: (* T12 kein Selbstanlauf der Spindel nach Quittierung *)
        IF tonStep.Q THEN
            IF GVL_IO.bSpindleRun THEN sMsg := 'T12 Spindel startet nach Quittierung von selbst'; bFailNow := TRUE; END_IF
            GVL_HMI.stCmd.bSpindleOn := FALSE;
            nStep := 160; tWait := T#500MS; bNext := TRUE;
        END_IF

    160: (* Ende *)
        IF tonStep.Q THEN
            bTestDone := TRUE;
            nStep := 170;
        END_IF

    170: ;
END_CASE

IF bFailNow THEN
    nFails := nFails + 1;
    IF sFirstFail = '' THEN sFirstFail := sMsg; END_IF
    bFailNow := FALSE;
END_IF
END_PROGRAM
