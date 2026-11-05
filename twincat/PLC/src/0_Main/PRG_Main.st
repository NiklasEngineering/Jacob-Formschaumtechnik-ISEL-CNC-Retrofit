(* Hauptprogramm. Aufrufreihenfolge fest: Eingaenge -> Sicherheit -> Achsen -> Meldungen ->
   Verriegelungen -> Zustand -> Geraete -> HMI-Status. Rueckwirkungen zwischen den Bausteinen
   laufen bewusst mit einem Zyklus Verzoegerung, damit keine Schleifen entstehen. *)
PROGRAM PRG_Main
VAR
    fbParam    : FB_ParamCheck;
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
    aAlarmId   : ARRAY[0..14] OF INT := [100, 101, 110, 120, 200, 201, 202, 203, 300, 301, 302, 310, 320, 330, 900];
    i          : INT;
    bStandstill: BOOL;
    bSimulation: BOOL := TRUE;     (* bis die Hardwareabbildung steht, immer Simulation *)
    nVersionDummy : INT;
    tonUptime  : TON;
    tonSpindleUptime : TON;
    dwSecTick  : UDINT;
    dtNow      : DT;
END_VAR

(* 1. Parameter *)
fbParam(nIdExpected := 1, nIdLoaded := GVL_Machine.stParams.nMachineId,
        sVerExpected := GVL_Machine.stParams.sSwVersionExpected, sVerRunning := '0.1.0',
        bParamsLoaded := GVL_Machine.bParamsLoaded);

(* 2. Sicherheit *)
fbSafety(bRelayFeedbackOk := GVL_IO.bSafetyRelayFeedback, bDoorClosed := GVL_IO.bDoorClosed,
         bFieldbusOk := GVL_IO.bFieldbusOk, bAck := GVL_HMI.stCmd.bAck, bAirOk := GVL_IO.bAirOk);

(* 3. Achsen *)
FOR i := 1 TO 4 DO
    GVL_IO.aAxis[i].bEnableReq := fbState.bEnableDrives;
    fbAxisSim[i](bSafeEnable := fbSafety.bDrivesAllowed, stAxis := GVL_IO.aAxis[i]);
END_FOR
fbSupervisor(bEnableCmd := fbState.bEnableDrives, bFieldbusOk := GVL_IO.bFieldbusOk,
             rMaxFollowErr := 1.0, aAxis := GVL_IO.aAxis);
bStandstill := fbSpindle.bStandstillOk AND fbState.eState <> E_MachState.Execute AND NOT fbJog.bJogPlusReq AND NOT fbJog.bJogMinusReq;

(* 4. Meldungen *)
aCond[0]  := NOT GVL_IO.bSafetyRelayFeedback;
aCond[1]  := NOT GVL_IO.bDoorClosed;
aCond[2]  := GVL_Machine.stParams.bAirMonitoring AND NOT GVL_IO.bAirOk;
aCond[3]  := NOT GVL_IO.bExtractionOk AND GVL_HMI.stSts.bExtractionOn;
aCond[4]  := NOT GVL_IO.bFuReady;
aCond[5]  := fbSpindle.bPtcTrip;
aCond[6]  := fbSpindle.bNoFeedback;
aCond[7]  := fbSpindle.bLockedSetup;
aCond[8]  := fbSupervisor.bAnyFault;
aCond[9]  := fbSupervisor.bFollowErr;
aCond[10] := fbSupervisor.bAnyHwLimit;
aCond[11] := NOT GVL_IO.bFieldbusOk;
aCond[12] := fbSupervisor.bHomingLost;
aCond[13] := NOT fbJog.bHmiLinkOk;
aCond[14] := fbParam.bMismatch;
fbAlarms(aCond := aCond, bAck := GVL_HMI.stCmd.bAck);
fbJournal(aCond := aCond, aId := aAlarmId, dtNow := dtNow);

(* 5. Betriebsart und Verriegelungen *)
fbMode(eRequest := GVL_HMI.stCmd.eModeRequest, bStandstill := bStandstill,
       bHasKeySwitch := FALSE, bKeyAuto := GVL_IO.bKeyAuto);
fbInterlocks(eMode := fbMode.eMode, eState := fbState.eState, bSafetyOk := fbSafety.bSafetyOk,
             bAllHomed := fbSupervisor.bAllHomed, bDrivesEnabled := fbSupervisor.bAllEnabled,
             bHmiLinkOk := fbJog.bHmiLinkOk, bAnyR2OrHigher := fbAlarms.bAnyR2OrHigher,
             bAnyR3OrHigher := fbAlarms.bAnyR3OrHigher, bAirOk := GVL_IO.bAirOk OR NOT GVL_Machine.stParams.bAirMonitoring);

(* 6. Zustand *)
fbState(bSafetyOk := fbSafety.bSafetyOk, bDrivesAllowed := fbSafety.bDrivesAllowed,
        bAnyR2OrHigher := fbAlarms.bAnyR2OrHigher, bAnyR3OrHigher := fbAlarms.bAnyR3OrHigher,
        bAnyR4 := fbAlarms.bAnyR4, bAckPending := fbAlarms.bAckPending,
        bStartOk := fbInterlocks.bProgramStartOk AND NOT fbTool.bHoldProgram,
        bStartCmd := GVL_HMI.stCmd.bStart, bHoldCmd := GVL_HMI.stCmd.bHold,
        bAbortCmd := GVL_HMI.stCmd.bAbort, bProgramDone := GVL_Machine.bCncProgramDone,
        bAck := GVL_HMI.stCmd.bAck);

(* 7. Geraete: Spindel (M3/M4 aus Programm, in Hand von der HMI) *)
fbMFunc(nMCode := GVL_Machine.nCncMCode, bMStrobe := GVL_Machine.bCncMStrobe,
        bSpindleOk := fbInterlocks.bSpindleOk, bAuxOk := fbInterlocks.bAuxOk);
fbSpindle(bRelease := fbInterlocks.bSpindleOk AND NOT fbState.bSpindleStop AND NOT fbTool.bSpindleLock,
          bSetupLocked := fbMode.eMode = E_OpMode.Setup OR GVL_HMI.stCmd.bDryRun,
          bStartCw := (fbMFunc.bSpindleCw AND fbMode.eMode = E_OpMode.Auto) OR (GVL_HMI.stCmd.bSpindleOn AND NOT GVL_HMI.stCmd.bSpindleCcw AND fbMode.eMode = E_OpMode.Hand),
          bStartCcw := (fbMFunc.bSpindleCcw AND fbMode.eMode = E_OpMode.Auto) OR (GVL_HMI.stCmd.bSpindleOn AND GVL_HMI.stCmd.bSpindleCcw AND fbMode.eMode = E_OpMode.Hand),
          rSetRpm := GVL_HMI.stCmd.rSpindleSetRpm, rOverridePct := 100.0,
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
fbHoming(bStart := GVL_HMI.stCmd.bHomeRequest, aStartAxis := GVL_HMI.stCmd.bHomeAxis,
         bAbort := GVL_HMI.stCmd.bAbort OR GVL_HMI.stCmd.bHomeAbort,
         bHomingOk := fbInterlocks.bHomingOk, aHomed := GVL_Machine.aCncHomed);
fbJog(bJogOk := fbInterlocks.bJogOk, bPlus := GVL_HMI.stCmd.bJogPlus, bMinus := GVL_HMI.stCmd.bJogMinus,
      nAxis := GVL_HMI.stCmd.nJogAxis, bRapid := GVL_HMI.stCmd.bJogRapid,
      nHeartbeat := GVL_HMI.stCmd.nHeartbeat, tHmiTimeout := GVL_Machine.stParams.tHmiTimeout);

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
tonUptime(IN := TRUE, PT := T#1S);
IF tonUptime.Q THEN dwSecTick := dwSecTick + 1; tonUptime(IN := FALSE); END_IF
GVL_HMI.stSts.eMode          := fbMode.eMode;
GVL_HMI.stSts.eState         := fbState.eState;
GVL_HMI.stSts.bSafetyOk      := fbSafety.bSafetyOk;
GVL_HMI.stSts.bDrivesEnabled := fbSupervisor.bAllEnabled;
GVL_HMI.stSts.bAllHomed      := fbSupervisor.bAllHomed;
GVL_HMI.stSts.bHmiLinkOk     := fbJog.bHmiLinkOk;
GVL_HMI.stSts.bSpindleRunning:= fbSpindle.bRunning;
GVL_HMI.stSts.rSpindleActRpm := fbSpindle.rActRpm;
GVL_HMI.stSts.bExtractionOn  := GVL_IO.bExtractionOut;
GVL_HMI.stSts.bBlowAirOn     := GVL_IO.bBlowAirOut;
GVL_HMI.stSts.bVacuumOn      := GVL_IO.bVacuumOut;
GVL_HMI.stSts.bToolChangeReq := fbTool.bRequest;
GVL_HMI.stSts.nToolChangeNo  := fbTool.nRequestedTool;
GVL_HMI.stSts.nTopAlarmId    := fbAlarms.nTopId;
GVL_HMI.stSts.eTopAlarmClass := F_ToFaultClass(fbAlarms.nTopClass);
GVL_HMI.stSts.nActiveAlarms  := fbAlarms.nActive;
GVL_HMI.stSts.nMachineId     := GVL_Machine.stParams.nMachineId;
GVL_HMI.stSts.sSwVersion     := '0.1.0';
GVL_HMI.stSts.dwOperatingSec := dwSecTick;
GVL_HMI.stSts.bHandwheelActive := GVL_Machine.bCncHandwheel;
GVL_HMI.stSts.eHomeState     := fbHoming.eHomeState;
GVL_HMI.stSts.nHomeStep      := fbHoming.nStepOut;
GVL_HMI.stSts.aAlarms        := fbAlarms.aList;
GVL_HMI.stSts.aDrive         := GVL_IO.aAxis;
GVL_HMI.stSts.bFieldbusOk    := GVL_IO.bFieldbusOk;
GVL_HMI.stSts.bFuFault       := NOT GVL_IO.bFuReady;
GVL_HMI.stSts.bPtcTrip       := fbSpindle.bPtcTrip;
END_PROGRAM
