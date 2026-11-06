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
    bHbStop     : BOOL;                 (* TRUE = simuliertes Lebenszeichen der HMI ausgefallen *)
    nIdx        : INT;
END_VAR

(* G-06: Der Test schreibt Sicherheitseingaenge und darf nur mit dem Simulationsabbild laufen *)
IF NOT (bTestEnable AND GVL_Config.bSimulationBuild AND GVL_Config.eDriveVariant = E_DriveVariant.Simulation) THEN
    bHbStop := FALSE;
    FOR nIdx := 1 TO 4 DO
        GVL_IO.aSimLimitPlus[nIdx] := FALSE;
        GVL_IO.aSimLimitMinus[nIdx] := FALSE;
        GVL_IO.aSimFault[nIdx] := FALSE;
    END_FOR
    IF nStep <> 0 THEN
        (* Test beendet oder abgebrochen: CNC-Stub einmalig zuruecknehmen *)
        GVL_Machine.bCncProgramActive := FALSE; GVL_Machine.bCncMStrobe := FALSE; GVL_Machine.nCncMCode := 0;
        GVL_Machine.rCncSpindleRpm := 0.0;
    END_IF
    nStep := 0;
    RETURN;
END_IF

(* Simulierte HMI: Lebenszeichen alle 100 ms. Simulierter Umrichter: Drehzahl erreicht folgt dem Start. *)
tonHb(IN := NOT tonHb.Q, PT := T#100MS);
IF tonHb.Q AND NOT bHbStop THEN GVL_HMI.stCmd.nHeartbeat := GVL_HMI.stCmd.nHeartbeat + 1; END_IF
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
            (* Eingaenge sind jetzt in Ordnung, aber ohne Quittierung darf die Maschine nicht frei sein (EStop oder Stopped) *)
            IF GVL_HMI.stSts.eState = E_MachState.Idle OR GVL_HMI.stSts.eState = E_MachState.Execute OR GVL_HMI.stSts.bDrivesEnabled THEN sMsg := 'T01 Anlauf ohne Quittierung frei'; bFailNow := TRUE; END_IF
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
            nStep := 160; tWait := T#11S; bNext := TRUE;   (* Auslaufzeit abwarten: Hand-Start waehrend des Auslaufs wird verworfen (G-11) *)
        END_IF

    160: (* Spindel erneut starten (Auslaufzeit abwarten), danach HMI-Verlust *)
        IF tonStep.Q THEN
            GVL_HMI.stCmd.bSpindleOn := TRUE;
            nStep := 170; tWait := T#13S; bNext := TRUE;
        END_IF

    170: (* T13a Spindel laeuft, dann Lebenszeichen der HMI ausfallen lassen *)
        IF tonStep.Q THEN
            IF NOT GVL_IO.bSpindleRun THEN sMsg := 'T13a Spindel startet nach Stillstand nicht'; bFailNow := TRUE; END_IF
            bHbStop := TRUE;
            nStep := 180; tWait := T#1500MS; bNext := TRUE;
        END_IF

    180: (* T13 Spindel stoppt bei HMI-Verlust, Meldung 330 steht *)
        IF tonStep.Q THEN
            IF GVL_IO.bSpindleRun THEN sMsg := 'T13 Spindel laeuft bei HMI-Verlust weiter'; bFailNow := TRUE; END_IF
            IF NOT GVL_HMI.stSts.aAlarms[13].bActive THEN sMsg := 'T13b Meldung 330 (HMI-Verbindung) fehlt'; bFailNow := TRUE; END_IF
            bHbStop := FALSE;
            nStep := 190; tWait := T#1500MS; bNext := TRUE;
        END_IF

    190: (* T14 kein Selbstanlauf der Spindel bei Rueckkehr der HMI *)
        IF tonStep.Q THEN
            IF GVL_IO.bSpindleRun THEN sMsg := 'T14 Spindel startet bei Rueckkehr der HMI von selbst'; bFailNow := TRUE; END_IF
            GVL_HMI.stCmd.bSpindleOn := FALSE;
            nStep := 300; tWait := T#500MS; bNext := TRUE;
        END_IF

    300: (* G-01 Endschalter: Tippen+ an X starten *)
        IF tonStep.Q THEN
            GVL_HMI.stCmd.nJogAxis := 1;
            GVL_HMI.stCmd.bJogPlus := TRUE;
            nStep := 305; tWait := T#500MS; bNext := TRUE;
        END_IF

    305: (* Ausgangslage: Tippen+ laeuft, dann Endschalter Plus an X ausloesen (Antrieb 3) *)
        IF tonStep.Q THEN
            IF NOT GVL_Machine.bCncJogPlus THEN sMsg := 'T15a Tippen+ startet nicht (Ausgangslage Endschalter)'; bFailNow := TRUE; END_IF
            GVL_IO.aSimLimitPlus[3] := TRUE;
            nStep := 310; tWait := T#400MS; bNext := TRUE;
        END_IF

    310: (* T15 Tippen stoppt am Endschalter, Meldung 302 steht *)
        IF tonStep.Q THEN
            IF GVL_Machine.bCncJogPlus THEN sMsg := 'T15 Tippen stoppt nicht am Endschalter'; bFailNow := TRUE; END_IF
            IF NOT GVL_HMI.stSts.aAlarms[10].bActive THEN sMsg := 'T15b Meldung 302 (Endschalter) fehlt'; bFailNow := TRUE; END_IF
            nStep := 320; tWait := T#400MS; bNext := TRUE;
        END_IF

    320: (* T15c Taste noch gehalten: kein erneuter Start. Dann Taste loslassen und in Richtung Endschalter neu druecken *)
        IF tonStep.Q THEN
            IF GVL_Machine.bCncJogPlus THEN sMsg := 'T15c Tippen startet am Endschalter bei gehaltener Taste erneut'; bFailNow := TRUE; END_IF
            GVL_HMI.stCmd.bJogPlus := FALSE;
            nStep := 325; tWait := T#300MS; bNext := TRUE;
        END_IF

    325:
        IF tonStep.Q THEN
            GVL_HMI.stCmd.bJogRapid := TRUE;
            GVL_HMI.stCmd.bJogPlus := TRUE;
            nStep := 330; tWait := T#400MS; bNext := TRUE;
        END_IF

    330: (* T15d Richtung zum Endschalter gesperrt. Dann Freifahren in Gegenrichtung *)
        IF tonStep.Q THEN
            IF GVL_Machine.bCncJogPlus THEN sMsg := 'T15d Tippen in Richtung Endschalter nicht gesperrt'; bFailNow := TRUE; END_IF
            GVL_HMI.stCmd.bJogPlus := FALSE;
            nStep := 335; tWait := T#300MS; bNext := TRUE;
        END_IF

    335:
        IF tonStep.Q THEN
            GVL_HMI.stCmd.bJogMinus := TRUE;
            nStep := 340; tWait := T#400MS; bNext := TRUE;
        END_IF

    340: (* T16 Freifahren Gegenrichtung moeglich, ohne Eilgang, anderer Achse gesperrt *)
        IF tonStep.Q THEN
            IF NOT GVL_Machine.bCncJogMinus THEN sMsg := 'T16 Freifahren in Gegenrichtung nicht moeglich'; bFailNow := TRUE; END_IF
            IF GVL_Machine.bCncJogRapid THEN sMsg := 'T16b Eilgang beim Freifahren'; bFailNow := TRUE; END_IF
            IF NOT GVL_Machine.bCncJogCreep THEN sMsg := 'T16c Schleichgang-Anforderung fehlt'; bFailNow := TRUE; END_IF
            GVL_HMI.stCmd.bJogMinus := FALSE;
            GVL_HMI.stCmd.bJogRapid := FALSE;
            GVL_HMI.stCmd.nJogAxis := 3;
            nStep := 345; tWait := T#300MS; bNext := TRUE;
        END_IF

    345: (* T16d Endschalter an X: Tippen an Z in beide Richtungen gesperrt *)
        IF tonStep.Q THEN
            GVL_HMI.stCmd.bJogPlus := TRUE;
            nStep := 347; tWait := T#400MS; bNext := TRUE;
        END_IF

    347:
        IF tonStep.Q THEN
            IF GVL_Machine.bCncJogPlus THEN sMsg := 'T16d Tippen an unbeteiligter Achse bei Endschalter erlaubt'; bFailNow := TRUE; END_IF
            GVL_HMI.stCmd.bJogPlus := FALSE;
            GVL_HMI.stCmd.nJogAxis := 1;
            GVL_IO.aSimLimitPlus[3] := FALSE;
            nStep := 350; tWait := T#400MS; bNext := TRUE;
        END_IF

    350: (* Endschalter frei, Meldung quittieren *)
        IF tonStep.Q THEN
            GVL_HMI.stCmd.bAck := TRUE;
            nStep := 360; tWait := T#1500MS; bNext := TRUE;
        END_IF

    360: (* T17 Quittierung nach Endschalter fuehrt nach Idle *)
        IF tonStep.Q THEN
            IF GVL_HMI.stSts.eState <> E_MachState.Idle THEN sMsg := 'T17 Quittierung nach Endschalter fuehrt nicht nach Idle'; bFailNow := TRUE; END_IF
            nStep := 398; tWait := T#6S; bNext := TRUE;   (* Spindel-Auslaufzeit abwarten, sonst wird der Wechsel nach Auto abgelehnt *)
        END_IF

    398: (* Betriebsart Auto anfordern *)
        IF tonStep.Q THEN
            GVL_HMI.stCmd.eModeRequest := E_OpMode.Auto;
            nStep := 400; tWait := T#700MS; bNext := TRUE;
        END_IF

    (* ---- Programmbetrieb mit CNC-Stub (solange TF5200 nicht angebunden ist) ---- *)
    400: (* T18 Auto, Programmstart *)
        IF tonStep.Q THEN
            IF GVL_HMI.stSts.eMode <> E_OpMode.Auto THEN sMsg := 'T18a Betriebsart Auto nicht erreicht'; bFailNow := TRUE; END_IF
            GVL_HMI.stCmd.bStart := TRUE;
            nStep := 405; tWait := T#500MS; bNext := TRUE;
        END_IF

    405: (* CNC meldet Programm aktiv, M3 S12000 *)
        IF tonStep.Q THEN
            IF GVL_HMI.stSts.eState <> E_MachState.Execute THEN sMsg := 'T18b Programmstart nicht angenommen'; bFailNow := TRUE; END_IF
            GVL_Machine.bCncProgramActive := TRUE;
            GVL_Machine.rCncSpindleRpm := 12000.0;
            GVL_Machine.nCncMCode := 3;
            GVL_Machine.bCncMStrobe := TRUE;
            nStep := 410; tWait := T#18S; bNext := TRUE;
        END_IF

    410: (* T19 M3 wird erst quittiert, wenn die Spindel laeuft *)
        IF GVL_Machine.bCncMAck AND NOT GVL_IO.bSpindleRun THEN
            sMsg := 'T19a M3 quittiert, obwohl die Spindel nicht laeuft'; bFailNow := TRUE;
            nStep := 415; tWait := T#300MS; bNext := TRUE;
        ELSIF GVL_IO.bSpindleRun AND GVL_Machine.bCncMAck THEN
            nStep := 415; tWait := T#300MS; bNext := TRUE;
        ELSIF tonStep.Q THEN
            sMsg := 'T19 Spindel startet nach M3 nicht'; bFailNow := TRUE;
            nStep := 415; tWait := T#300MS; bNext := TRUE;
        END_IF

    415: (* T19c S-Wert aus der CNC wirkt, dann M-Code zurueckziehen und Halt *)
        IF tonStep.Q THEN
            IF ABS(GVL_IO.rSpindleVolt - 7.2) > 0.3 THEN sMsg := 'T19c S-Wert aus der CNC nicht uebernommen'; bFailNow := TRUE; END_IF
            GVL_Machine.bCncMStrobe := FALSE; GVL_Machine.nCncMCode := 0;
            GVL_HMI.stCmd.bHold := TRUE;
            nStep := 420; tWait := T#800MS; bNext := TRUE;
        END_IF

    420: (* T20 Vorschubhalt: Zustand Held, Anforderung an die CNC als Pegel *)
        IF tonStep.Q THEN
            IF GVL_HMI.stSts.eState <> E_MachState.Held THEN sMsg := 'T20 Halt nicht angenommen'; bFailNow := TRUE; END_IF
            nStep := 425; tWait := T#2S; bNext := TRUE;
        END_IF

    425:
        IF tonStep.Q THEN
            IF NOT GVL_Machine.bCncHoldReq THEN sMsg := 'T20b Vorschubhalt faellt ab (kein Pegel)'; bFailNow := TRUE; END_IF
            GVL_HMI.stCmd.bStart := TRUE;
            nStep := 430; tWait := T#500MS; bNext := TRUE;
        END_IF

    430: (* T20c Fortsetzen, Halt faellt; dann Vakuum per M10 *)
        IF tonStep.Q THEN
            IF GVL_HMI.stSts.eState <> E_MachState.Execute THEN sMsg := 'T20c Fortsetzen nach Halt nicht moeglich'; bFailNow := TRUE; END_IF
            IF GVL_Machine.bCncHoldReq THEN sMsg := 'T20d Halt bleibt nach Fortsetzen stehen'; bFailNow := TRUE; END_IF
            GVL_Machine.nCncMCode := 10; GVL_Machine.bCncMStrobe := TRUE;
            nStep := 435; tWait := T#400MS; bNext := TRUE;
        END_IF

    435: (* T21a Vakuum an, dann Abbruch *)
        IF tonStep.Q THEN
            IF NOT GVL_IO.bVacuumOut THEN sMsg := 'T21a Vakuum (M10) geht nicht an'; bFailNow := TRUE; END_IF
            GVL_Machine.bCncMStrobe := FALSE; GVL_Machine.nCncMCode := 0;
            GVL_HMI.stCmd.bAbort := TRUE;
            nStep := 440; tWait := T#700MS; bNext := TRUE;
        END_IF

    440: (* T21 Abbruch: Spindel aus, Abbruch an die CNC als Pegel, Vakuum bleibt (G-04) *)
        IF tonStep.Q THEN
            IF GVL_IO.bSpindleRun THEN sMsg := 'T21 Spindel laeuft nach Abbruch weiter'; bFailNow := TRUE; END_IF
            IF NOT GVL_Machine.bCncAbortReq THEN sMsg := 'T21b Abbruch an die CNC fehlt'; bFailNow := TRUE; END_IF
            IF NOT GVL_IO.bVacuumOut THEN sMsg := 'T21c Vakuum faellt bei Abbruch ab'; bFailNow := TRUE; END_IF
            GVL_Machine.bCncProgramActive := FALSE;
            nStep := 445; tWait := T#500MS; bNext := TRUE;
        END_IF

    445: (* T21d Abbruch faellt, wenn die CNC steht. Quittieren, dann M11 *)
        IF tonStep.Q THEN
            IF GVL_Machine.bCncAbortReq THEN sMsg := 'T21d Abbruch bleibt nach Programmstopp stehen'; bFailNow := TRUE; END_IF
            GVL_HMI.stCmd.bAck := TRUE;
            nStep := 450; tWait := T#1500MS; bNext := TRUE;
        END_IF

    450: (* M11 schaltet das Vakuum ab, Zustand Idle *)
        IF tonStep.Q THEN
            IF GVL_HMI.stSts.eState <> E_MachState.Idle THEN sMsg := 'T21e Quittierung nach Abbruch fuehrt nicht nach Idle'; bFailNow := TRUE; END_IF
            GVL_Machine.nCncMCode := 11; GVL_Machine.bCncMStrobe := TRUE;
            nStep := 455; tWait := T#400MS; bNext := TRUE;
        END_IF

    455: (* T21f M11 aus, dann Programm neu starten, Vakuum an, NOT-HALT in Execute *)
        IF tonStep.Q THEN
            IF GVL_IO.bVacuumOut THEN sMsg := 'T21f M11 schaltet das Vakuum nicht ab'; bFailNow := TRUE; END_IF
            GVL_Machine.bCncMStrobe := FALSE; GVL_Machine.nCncMCode := 0;
            GVL_HMI.stCmd.bStart := TRUE;
            nStep := 460; tWait := T#500MS; bNext := TRUE;
        END_IF

    460:
        IF tonStep.Q THEN
            IF GVL_HMI.stSts.eState <> E_MachState.Execute THEN sMsg := 'T22a Programmstart nach Abbruch nicht moeglich'; bFailNow := TRUE; END_IF
            GVL_Machine.bCncProgramActive := TRUE;
            GVL_Machine.nCncMCode := 10; GVL_Machine.bCncMStrobe := TRUE;
            nStep := 465; tWait := T#400MS; bNext := TRUE;
        END_IF

    465: (* NOT-HALT in Execute bei aktiver CNC *)
        IF tonStep.Q THEN
            GVL_Machine.bCncMStrobe := FALSE; GVL_Machine.nCncMCode := 0;
            bRelay := FALSE;
            nStep := 470; tWait := T#600MS; bNext := TRUE;
        END_IF

    470: (* T22 EStop, Abbruch an die CNC, Vakuum bleibt (G-04). Sicherheitskreis wieder zu, quittieren: CNC aktiv, EStop bleibt *)
        IF tonStep.Q THEN
            IF GVL_HMI.stSts.eState <> E_MachState.EStop THEN sMsg := 'T22 NOT-HALT in Execute nicht erkannt'; bFailNow := TRUE; END_IF
            IF NOT GVL_Machine.bCncAbortReq THEN sMsg := 'T22b NOT-HALT in Execute: kein Abbruch an die CNC'; bFailNow := TRUE; END_IF
            IF NOT GVL_IO.bVacuumOut THEN sMsg := 'T22c Vakuum faellt bei NOT-HALT ab'; bFailNow := TRUE; END_IF
            bRelay := TRUE;
            nStep := 475; tWait := T#500MS; bNext := TRUE;
        END_IF

    475:
        IF tonStep.Q THEN
            GVL_HMI.stCmd.bAck := TRUE;
            nStep := 480; tWait := T#800MS; bNext := TRUE;
        END_IF

    480: (* T22d EStop bleibt, solange die CNC noch aktiv meldet *)
        IF tonStep.Q THEN
            IF GVL_HMI.stSts.eState <> E_MachState.EStop THEN sMsg := 'T22d EStop verlassen, obwohl die CNC noch aktiv ist'; bFailNow := TRUE; END_IF
            GVL_Machine.bCncProgramActive := FALSE;
            nStep := 485; tWait := T#500MS; bNext := TRUE;
        END_IF

    485:
        IF tonStep.Q THEN
            GVL_HMI.stCmd.bAck := TRUE;
            nStep := 490; tWait := T#1500MS; bNext := TRUE;
        END_IF

    490: (* T22e Quittierung nach CNC-Stopp fuehrt nach Idle; M11 raeumt auf, zurueck in Hand *)
        IF tonStep.Q THEN
            IF GVL_HMI.stSts.eState <> E_MachState.Idle THEN sMsg := 'T22e Quittierung nach CNC-Stopp fuehrt nicht nach Idle'; bFailNow := TRUE; END_IF
            GVL_Machine.nCncMCode := 11; GVL_Machine.bCncMStrobe := TRUE;
            GVL_HMI.stCmd.eModeRequest := E_OpMode.Hand;
            nStep := 495; tWait := T#600MS; bNext := TRUE;
        END_IF

    495:
        IF tonStep.Q THEN
            GVL_Machine.bCncMStrobe := FALSE; GVL_Machine.nCncMCode := 0;
            GVL_Machine.rCncSpindleRpm := 0.0;
            nStep := 200; tWait := T#300MS; bNext := TRUE;
        END_IF

    200: (* Ende *)
        IF tonStep.Q THEN
            bTestDone := TRUE;
            nStep := 210;
        END_IF

    210: ;
END_CASE

IF bFailNow THEN
    nFails := nFails + 1;
    IF sFirstFail = '' THEN sFirstFail := sMsg; END_IF
    bFailNow := FALSE;
END_IF
END_PROGRAM
