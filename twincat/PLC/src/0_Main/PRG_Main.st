(* Hauptprogramm. Aufrufreihenfolge fest: Eingaenge -> Sicherheit -> Achsen -> Meldungen ->
   Verriegelungen -> Zustand -> Geraete -> HMI-Status. Rueckwirkungen zwischen den Bausteinen
   laufen bewusst mit einem Zyklus Verzoegerung, damit keine Schleifen entstehen. *)
PROGRAM PRG_Main
VAR
    fbParamInit: FB_ParamInit;
    fbCncMirror: FB_CncMirror;
    fbParam    : FB_ParamCheck;
    aGrpOfAxis : ARRAY[1..4] OF INT := [3, 3, 2, 1];   (* Achse 1,2 (Y1,Y2) = Gruppe 3, Achse 3 (X) = Gruppe 2, Achse 4 (Z) = Gruppe 1 *)
    fbSafety   : FB_SafetyMonitor;
    fbAxisSim  : ARRAY[1..4] OF FB_AxisMap_Simulation;
    fbSupervisor : FB_AxisSupervisor;
    fbAlarms   : FB_AlarmList;
    fbJournal  : FB_AlarmJournal;
    fbInterlocks : FB_Interlocks;
    fbState    : FB_MachineState;
    fbMode     : FB_OpModeManager;
    fbSpindle  : FB_Spindle;
    fbMFunc    : FB_MFunctions;
    fbTool     : FB_ToolChange;
    fbHoming   : FB_Homing;
    fbJog      : FB_Jog;
    aCond      : ARRAY[0..14] OF BOOL;
    aHomeReq   : ARRAY[1..3] OF BOOL;
    fbAxisCan  : ARRAY[1..4] OF FB_AxisMap_Canopen;
    tonExtraction : TON;
    i          : INT;
    bStandstill: BOOL;
    bSimulation: BOOL := TRUE;     (* bis die Hardwareabbildung steht, immer Simulation *)
    nVersionDummy : INT;
    tonUptime  : TON;
    tonSpindleUptime : TON;
    dwSecTick  : UDINT;
    dtNow      : DT;
    nMachineIdEff : UINT;     (* wirksame Maschinenkennung (Befund 20) *)
    nSysTime   : ULINT;       (* UTC, 100 ns seit 1.1.1601 *)
    bLimitFreeRun : BOOL;     (* Freifahren vom Endschalter erlaubt (Befund 15) *)
    bOtherR3   : BOOL;
    nCls       : INT;
    bHandSpindleBlock : BOOL; (* Hand-Spindel gesperrt bis bSpindleOn einmal FALSE war (Lebenszeichen weg, nicht Hand) *)
    bHandSpindleOn : BOOL;    (* wirksame Hand-Anforderung Spindel *)
    tofModeBlocked : TOF;     (* Hinweis "Betriebsartwechsel abgelehnt" fuer die HMI halten *)
END_VAR

(* 1. Parameter: initialisieren und pruefen, bei unplausiblen Werten bleibt die Maschine gesperrt *)
(* Befund 20: Kennung aus dem Geraet (persistent), nur im Simulationsbuild Ersatzwert bei 0 *)
nMachineIdEff := GVL_Persistent.nMachineId;
IF nMachineIdEff = 0 AND GVL_Config.bSimulationBuild THEN nMachineIdEff := GVL_Config.nMachineIdSimDefault; END_IF
fbParamInit(nMachineId := nMachineIdEff, stParams := GVL_Machine.stParams);
GVL_Machine.bParamsLoaded := fbParamInit.bLoaded;
fbParam(nIdExpected := nMachineIdEff, nIdLoaded := GVL_Machine.stParams.nMachineId,
        sVerExpected := GVL_Machine.stParams.sSwVersionExpected, sVerRunning := GVL_Config.sSwVersion,
        bParamsLoaded := GVL_Machine.bParamsLoaded);

(* 2. Sicherheit *)
fbSafety(bRelayFeedbackOk := GVL_IO.bSafetyRelayFeedback, bDoorClosed := GVL_IO.bDoorClosed,
         bFieldbusOk := GVL_IO.bFieldbusOk, bAck := GVL_HMI.stCmd.bAck, bAirOk := GVL_IO.bAirOk);

(* 3. Achsen *)
FOR i := 1 TO 4 DO
    GVL_IO.aAxis[i].bEnableReq := fbState.bEnableDrives;
    GVL_IO.aAxis[i].bResetReq  := GVL_HMI.stCmd.bAck;     (* Antriebsfehler quittieren (Befund 14) *)
    IF GVL_Config.eDriveVariant = E_DriveVariant.Simulation THEN
    fbAxisSim[i](bSafeEnable := fbSafety.bDrivesAllowed,
                 bHomeReset := fbHoming.aResetHomed[aGrpOfAxis[i]],
                 bHomeCmd := fbHoming.bHomeCmd AND fbHoming.nActiveGroup = aGrpOfAxis[i],
                 stAxis := GVL_IO.aAxis[i]);
    ELSE
        (* Befund 9: echte Abbildung fehlt, FB_AxisMap_Canopen sperrt die Maschine (Fehler FFFF0001) *)
        fbAxisCan[i](bSafeEnable := fbSafety.bDrivesAllowed, stAxis := GVL_IO.aAxis[i]);
    END_IF
END_FOR
(* Einheitlicher Referenzstatus (Befund 3): einzige Quelle ist GVL_IO.aAxis[].bHomed.
   Gruppen 1 = Z, 2 = X, 3 = Y (beide Portalseiten). *)
GVL_Machine.aCncHomed[1] := GVL_IO.aAxis[4].bHomed;
GVL_Machine.aCncHomed[2] := GVL_IO.aAxis[3].bHomed;
GVL_Machine.aCncHomed[3] := GVL_IO.aAxis[1].bHomed AND GVL_IO.aAxis[2].bHomed;
GVL_HmiCnc.stCncSts.aAxis[1].bHomed := GVL_Machine.aCncHomed[2];   (* HMI-Achse 1 = X *)
GVL_HmiCnc.stCncSts.aAxis[2].bHomed := GVL_Machine.aCncHomed[3];   (* HMI-Achse 2 = Y *)
GVL_HmiCnc.stCncSts.aAxis[3].bHomed := GVL_Machine.aCncHomed[1];   (* HMI-Achse 3 = Z *)
fbSupervisor(bEnableCmd := fbState.bEnableDrives, bFieldbusOk := GVL_IO.bFieldbusOk,
             bHomingActive := fbHoming.bBusy, rMaxFollowErr := 1.0, aAxis := GVL_IO.aAxis);
bStandstill := fbSpindle.bStandstillOk AND fbState.eState <> E_MachState.Execute AND NOT fbJog.bJogPlusReq AND NOT fbJog.bJogMinusReq;

(* 4. Meldungen *)
aCond[0]  := NOT GVL_IO.bSafetyRelayFeedback;
aCond[1]  := NOT GVL_IO.bDoorClosed;
aCond[2]  := GVL_Machine.stParams.bAirMonitoring AND NOT GVL_IO.bAirOk;
(* Absaugung: Rueckmeldung darf nach dem Einschalten tFeedbackTimeout dauern (Befund 12) *)
tonExtraction(IN := NOT GVL_IO.bExtractionOk AND GVL_IO.bExtractionOut, PT := GVL_Machine.stParams.tFeedbackTimeout);
aCond[3]  := tonExtraction.Q;
aCond[4]  := NOT GVL_IO.bFuReady;
aCond[5]  := fbSpindle.bPtcTrip;
aCond[6]  := fbSpindle.bNoFeedback;
aCond[7]  := fbSpindle.bLockedSetup;
aCond[8]  := fbSupervisor.bAnyFault OR fbSupervisor.bEnableTimeout;
aCond[9]  := fbSupervisor.bFollowErr;
aCond[10] := fbSupervisor.bAnyHwLimit;
aCond[11] := NOT GVL_IO.bFieldbusOk;
aCond[12] := fbSupervisor.bHomingLost;
aCond[13] := NOT fbJog.bHmiLinkOk;
aCond[14] := fbParam.bMismatch;
fbAlarms(aCond := aCond, bAck := GVL_HMI.stCmd.bAck);
(* Befund 21: Zeitstempel UTC, Journal persistent, HMI liest die Kopie *)
nSysTime := F_GetSystemTime();
IF nSysTime > 116444736000000000 THEN
    dtNow := DWORD_TO_DT(ULINT_TO_DWORD((nSysTime - 116444736000000000) / 10000000));
END_IF
fbJournal(aCond := aCond, aId := GVL_AlarmCatalog.aAlarmId, aClass := GVL_AlarmCatalog.aAlarmClass,
          dtNow := dtNow, stJournal := GVL_Persistent.stJournal);
GVL_HMI.stJournal := GVL_Persistent.stJournal;

(* Befund 15: Steht nur der Endschalter (302, R3) an, darf in Hand im Schleichgang freigefahren werden.
   [offen] Richtungssperre zur Endschalterseite liegt in CNC/Antrieb (Softwareendlage, Endschalterlogik). *)
bOtherR3 := FALSE;
FOR i := 0 TO 14 DO
    nCls := GVL_AlarmCatalog.aAlarmClass[i];
    IF i <> 10 (* E_AlarmSlot.HwLimitHit *) AND nCls >= 3 AND (fbAlarms.aList[i].bActive OR fbAlarms.aList[i].bLatched) THEN
        bOtherR3 := TRUE;
    END_IF
END_FOR
bLimitFreeRun := aCond[10] AND NOT bOtherR3;   (* Slot 10 = E_AlarmSlot.HwLimitHit *)

(* 5. Betriebsart und Verriegelungen *)
(* Befund 17: Wechsel nur im echten Stillstand, ohne Referenzfahrt und ohne offene Werkzeugwechsel-Aufforderung *)
fbMode(eRequest := GVL_HMI.stCmd.eModeRequest,
       bStandstill := bStandstill AND fbInterlocks.bModeChangeOk AND NOT fbHoming.bBusy AND NOT fbTool.bRequest,
       bHasKeySwitch := FALSE, bKeyAuto := GVL_IO.bKeyAuto);
(* Abgelehnter Wunsch wird verworfen, sonst fuehrte die SPS ihn beim naechsten Stillstand verspaetet aus.
   Der Hinweis bleibt 3 s fuer die HMI stehen. *)
IF fbMode.bChangeBlocked THEN
    GVL_HMI.stCmd.eModeRequest := fbMode.eMode;
END_IF
tofModeBlocked(IN := fbMode.bChangeBlocked, PT := T#3S);
fbInterlocks(eMode := fbMode.eMode, eState := fbState.eState, bSafetyOk := fbSafety.bSafetyOk,
             bAllHomed := fbSupervisor.bAllHomed, bDrivesEnabled := fbSupervisor.bAllEnabled,
             bHmiLinkOk := fbJog.bHmiLinkOk, bAnyR2OrHigher := fbAlarms.bAnyR2OrHigher,
             bAnyR3OrHigher := fbAlarms.bAnyR3OrHigher, bAirOk := GVL_IO.bAirOk OR NOT GVL_Machine.stParams.bAirMonitoring,
             bHomingBusy := fbHoming.bBusy, bLimitFreeRun := bLimitFreeRun);

(* 6. Zustand *)
fbState(bSafetyOk := fbSafety.bSafetyOk, bDrivesAllowed := fbSafety.bDrivesAllowed,
        bAnyR2OrHigher := fbAlarms.bAnyR2OrHigher, bAnyR3OrHigher := fbAlarms.bAnyR3OrHigher,
        bAnyR4 := fbAlarms.bAnyR4, bAckPending := fbAlarms.bAckPending,
        bStartOk := fbInterlocks.bProgramStartOk AND NOT fbTool.bHoldProgram,
        bStartCmd := GVL_HMI.stCmd.bStart, bHoldCmd := GVL_HMI.stCmd.bHold OR fbMFunc.bProgramHalt,
        bAbortCmd := GVL_HMI.stCmd.bAbort, bProgramDone := GVL_Machine.bCncProgramDone,
        bProgramActive := GVL_Machine.bCncProgramActive,
        bAck := GVL_HMI.stCmd.bAck, tR4OffDelay := GVL_Config.tR4DriveOffDelay);

(* 7. Geraete: Spindel (M3/M4 aus Programm, in Hand von der HMI) *)
(* Hand-Spindel: Nach Lebenszeichenverlust oder ausserhalb Hand setzt die SPS bSpindleOn zurueck und sperrt,
   bis bSpindleOn FALSE gesehen wurde. Ein stehender Pegel startet die Spindel so nie von selbst wieder. *)
IF NOT fbJog.bHmiLinkOk OR fbMode.eMode <> E_OpMode.Hand THEN
    bHandSpindleBlock := TRUE;
    GVL_HMI.stCmd.bSpindleOn := FALSE;
ELSIF NOT GVL_HMI.stCmd.bSpindleOn THEN
    bHandSpindleBlock := FALSE;
END_IF
bHandSpindleOn := GVL_HMI.stCmd.bSpindleOn AND NOT bHandSpindleBlock;
fbMFunc(nMCode := GVL_Machine.nCncMCode, bMStrobe := GVL_Machine.bCncMStrobe,
        bSpindleOk := fbInterlocks.bSpindleOk, bAuxOk := fbInterlocks.bAuxOk,
        bReset := fbState.bSpindleStop OR GVL_Machine.bCncProgramDone, bOptStop := GVL_HMI.stCmd.bOptStop);
fbSpindle(bRelease := fbInterlocks.bSpindleOk AND NOT fbState.bSpindleStop AND NOT fbTool.bSpindleLock,
          bStop := fbState.bSpindleStop,
          bSetupLocked := fbMode.eMode = E_OpMode.Setup OR GVL_HMI.stCmd.bDryRun,
          bStartCw := (fbMFunc.bSpindleCw AND fbMode.eMode = E_OpMode.Auto) OR (bHandSpindleOn AND NOT GVL_HMI.stCmd.bSpindleCcw),
          bStartCcw := (fbMFunc.bSpindleCcw AND fbMode.eMode = E_OpMode.Auto) OR (bHandSpindleOn AND GVL_HMI.stCmd.bSpindleCcw),
          rSetRpm := SEL(fbMode.eMode = E_OpMode.Auto, GVL_HMI.stCmd.rSpindleSetRpm, GVL_Machine.rCncSpindleRpm),
          rOverridePct := UINT_TO_REAL(GVL_HmiCnc.stCncSts.nOvrSpindle),
          bFuReady := GVL_IO.bFuReady, bFuAtSpeed := GVL_IO.bFuAtSpeed, bPtcOk := GVL_IO.bSpindlePtcOk,
          bAckReset := GVL_HMI.stCmd.bAck, rMaxRpm := GVL_Machine.stParams.rSpindleMaxRpm,
          rMinRpm := GVL_Machine.stParams.rSpindleMinRpm, rVoltMax := GVL_Machine.stParams.rSpindleVoltMax,
          tRunUp := GVL_Machine.stParams.tSpindleRunUp, tStandstill := GVL_Machine.stParams.tSpindleStandstill);
GVL_IO.bSpindleRun  := fbSpindle.bRunCmd;
GVL_IO.bSpindleCcw  := fbSpindle.bDirCcw;
GVL_IO.rSpindleVolt := fbSpindle.rVoltOut;

fbTool(bM6Request := fbMFunc.bToolChangeReq, nToolNo := GVL_Machine.nCncToolNo,
       bSpindleStopped := fbSpindle.bStandstillOk, bConfirm := GVL_HMI.stCmd.bToolChangeDone,
       bAbort := GVL_HMI.stCmd.bAbort);

(* Hilfsausgaenge: von Hand oder per M-Code, nur mit Freigabe *)
GVL_IO.bExtractionOut := fbInterlocks.bAuxOk AND (fbMFunc.bExtraction OR GVL_HMI.stCmd.bExtraction);
GVL_IO.bBlowAirOut    := fbInterlocks.bAuxOk AND (fbMFunc.bBlowAir OR GVL_HMI.stCmd.bBlowAir);
GVL_IO.bVacuumOut     := fbInterlocks.bAuxOk AND (fbMFunc.bVacuum OR GVL_HMI.stCmd.bVacuum);

(* 8. Referenzieren und Tippen *)
(* Zuordnung HMI-Achse (1=X, 2=Y, 3=Z) zu Referenzgruppe (1=Z, 2=X, 3=Y) *)
aHomeReq[1] := GVL_HMI.stCmd.bHomeAxis[3];
aHomeReq[2] := GVL_HMI.stCmd.bHomeAxis[1];
aHomeReq[3] := GVL_HMI.stCmd.bHomeAxis[2];
fbHoming(bStart := GVL_HMI.stCmd.bHomeRequest, aStartAxis := aHomeReq,
         bAbort := GVL_HMI.stCmd.bAbort OR GVL_HMI.stCmd.bHomeAbort,
         bHomingOk := fbInterlocks.bHomingOk, aHomed := GVL_Machine.aCncHomed);
fbJog(bJogOk := fbInterlocks.bJogOk, bPlus := GVL_HMI.stCmd.bJogPlus, bMinus := GVL_HMI.stCmd.bJogMinus,
      nAxis := GVL_HMI.stCmd.nJogAxis, bRapid := GVL_HMI.stCmd.bJogRapid AND NOT bLimitFreeRun,
      nHeartbeat := GVL_HMI.stCmd.nHeartbeat, tHmiTimeout := GVL_Machine.stParams.tHmiTimeout);

(* CNC-Spiegel (Simulation, bis TF5200 verfuegbar ist) *)
fbCncMirror(bStandstill := fbState.eState <> E_MachState.Execute AND fbState.eState <> E_MachState.Held
                           AND NOT GVL_Machine.bCncProgramActive,
            stCmd := GVL_HmiCnc.stCncCmd, stSts := GVL_HmiCnc.stCncSts);

(* 9. Anforderungen an die CNC *)
GVL_Machine.bCncStartReq := fbState.bCncStart;
GVL_Machine.bCncHoldReq  := fbState.bCncHold OR fbTool.bHoldProgram;
GVL_Machine.bCncAbortReq := fbState.bCncAbort;
GVL_Machine.bCncMAck     := fbMFunc.bAck;
GVL_Machine.bCncJogPlus  := fbJog.bJogPlusReq;
GVL_Machine.bCncJogMinus := fbJog.bJogMinusReq;
GVL_Machine.nCncJogAxis  := fbJog.nAxisReq;
GVL_Machine.bCncJogRapid := fbJog.bRapidReq;
GVL_Machine.bCncHomeReq  := fbHoming.bHomeCmd;
GVL_Machine.nCncHomeGroup:= fbHoming.nActiveGroup;
GVL_Machine.bCncSingleBlock := GVL_HMI.stCmd.bSingleBlock;
GVL_Machine.bCncDryRun   := GVL_HMI.stCmd.bDryRun;
GVL_Machine.bCncOptStop  := GVL_HMI.stCmd.bOptStop;
GVL_Machine.rCncJogStepMm := GVL_HMI.stCmd.rJogStepMm;
(* Handrad: nur freigegeben, wenn vorhanden, in Hand und Tippen erlaubt *)
GVL_Machine.bCncHandwheel := GVL_Machine.bHasHandwheel AND GVL_HMI.stCmd.bHandwheelEnable AND fbInterlocks.bJogOk;
GVL_Machine.nCncHandwheelAxis  := GVL_HMI.stCmd.nHandwheelAxis;
GVL_Machine.nCncHandwheelRatio := GVL_HMI.stCmd.nHandwheelRatio;

(* 10. Status an die HMI *)
(* Befund 21: Betriebs- und Spindellaufzeit persistent, Sekundentakt *)
tonUptime(IN := TRUE, PT := T#1S);
IF tonUptime.Q THEN
    dwSecTick := dwSecTick + 1;
    GVL_Persistent.nOperatingSec := GVL_Persistent.nOperatingSec + 1;
    IF fbSpindle.bRunCmd THEN GVL_Persistent.nSpindleSec := GVL_Persistent.nSpindleSec + 1; END_IF
    tonUptime(IN := FALSE);
END_IF
GVL_HMI.stSts.eMode          := fbMode.eMode;
GVL_HMI.stSts.eState         := fbState.eState;
GVL_HMI.stSts.bSafetyOk      := fbSafety.bSafetyOk;
GVL_HMI.stSts.bDrivesEnabled := fbSupervisor.bAllEnabled;
GVL_HMI.stSts.bAllHomed      := fbSupervisor.bAllHomed;
GVL_HMI.stSts.bHmiLinkOk     := fbJog.bHmiLinkOk;
GVL_HMI.stSts.bSpindleRunning:= fbSpindle.bRunning;
GVL_HMI.stSts.rSpindleActRpm := SEL(fbSpindle.bRunning, 0.0, fbSpindle.rActRpm);   (* Sollwert nur bei Drehzahl erreicht anzeigen (Befund 13) *)
GVL_HMI.stSts.bExtractionOn  := GVL_IO.bExtractionOut;
GVL_HMI.stSts.bBlowAirOn     := GVL_IO.bBlowAirOut;
GVL_HMI.stSts.bVacuumOn      := GVL_IO.bVacuumOut;
GVL_HMI.stSts.bToolChangeReq := fbTool.bRequest;
GVL_HMI.stSts.nToolChangeNo  := fbTool.nRequestedTool;
GVL_HMI.stSts.nTopAlarmId    := fbAlarms.nTopId;
GVL_HMI.stSts.eTopAlarmClass := F_ToFaultClass(fbAlarms.nTopClass);
GVL_HMI.stSts.nActiveAlarms  := fbAlarms.nActive;
GVL_HMI.stSts.nMachineId     := GVL_Machine.stParams.nMachineId;
GVL_HMI.stSts.sSwVersion     := GVL_Config.sSwVersion;
GVL_HMI.stSts.bSimulationActive := GVL_Config.bSimulationBuild;
GVL_HMI.stSts.bModeChangeBlocked := tofModeBlocked.Q;
GVL_HMI.stSts.dwOperatingSec := GVL_Persistent.nOperatingSec;
GVL_HMI.stSts.dwSpindleSec   := GVL_Persistent.nSpindleSec;
GVL_HMI.stSts.nHeartbeatEcho := GVL_HMI.stCmd.nHeartbeat;
GVL_HMI.stSts.bLimitFreeRun  := bLimitFreeRun;
GVL_HMI.stSts.bHandwheelActive := GVL_Machine.bCncHandwheel;
GVL_HMI.stSts.eHomeState[1]  := fbHoming.eHomeState[2];   (* X *)
GVL_HMI.stSts.eHomeState[2]  := fbHoming.eHomeState[3];   (* Y *)
GVL_HMI.stSts.eHomeState[3]  := fbHoming.eHomeState[1];   (* Z *)
GVL_HMI.stSts.nHomeStep      := fbHoming.nStepOut;
GVL_HMI.stSts.aAlarms        := fbAlarms.aList;
GVL_HMI.stSts.aDrive         := GVL_IO.aAxis;
GVL_HMI.stSts.bFieldbusOk    := GVL_IO.bFieldbusOk;
GVL_HMI.stSts.bFuFault       := NOT GVL_IO.bFuReady;
GVL_HMI.stSts.bPtcTrip       := fbSpindle.bPtcTrip;

(* 11. Befund 16: Impulse aus der HMI loescht die SPS nach der Auswertung in diesem Zyklus.
   Die HMI setzt nur TRUE (Einzelfeld schreiben, nicht die ganze Struktur), ein Impuls geht so nie verloren. *)
GVL_HMI.stCmd.bStart          := FALSE;
GVL_HMI.stCmd.bHold           := FALSE;
GVL_HMI.stCmd.bAbort          := FALSE;
GVL_HMI.stCmd.bAck            := FALSE;
GVL_HMI.stCmd.bHomeRequest    := FALSE;
GVL_HMI.stCmd.bHomeAbort      := FALSE;
GVL_HMI.stCmd.bToolChangeDone := FALSE;
GVL_HMI.stCmd.bHomeAxis[1]    := FALSE;
GVL_HMI.stCmd.bHomeAxis[2]    := FALSE;
GVL_HMI.stCmd.bHomeAxis[3]    := FALSE;
GVL_HmiCnc.stCncCmd.bProgramLoad   := FALSE;
GVL_HmiCnc.stCncCmd.bTableWrite    := FALSE;
GVL_HmiCnc.stCncCmd.bWcsSetCurrent := FALSE;
END_PROGRAM
