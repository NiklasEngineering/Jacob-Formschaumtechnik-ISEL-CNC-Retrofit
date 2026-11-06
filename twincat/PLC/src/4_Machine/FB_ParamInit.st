(* Initialisiert die Maschinenparameter und prueft sie auf Plausibilitaet (Befunde 2 und 20).
   Der Parametersatz wird nach der Maschinenkennung des Geraets (GVL_Persistent.nMachineId) gewaehlt,
   damit ein Softwarestand fuer alle Maschinen gilt. Unbekannte Kennung: kein Satz, Maschine gesperrt.
   Uebergangsloesung: Werte stehen hier als Konstanten und entsprechen config/M1.json. Alle Werte ausser
   rSpindleMaxRpm sind Annahmen. Spaeter ersetzt ein Lader (Tc3_JsonXml) die Zuweisungen, die Pruefung bleibt.
   bLoaded wird nur TRUE, wenn alle Werte plausibel sind. *)
FUNCTION_BLOCK FB_ParamInit
VAR_INPUT
    nMachineId : UINT;            (* Kennung des Geraets *)
END_VAR
VAR_IN_OUT
    stParams : ST_MachineParams;
END_VAR
VAR_OUTPUT
    bLoaded  : BOOL;
    bInvalid : BOOL;
    bUnknownId : BOOL;            (* keine Parameter fuer diese Kennung *)
END_VAR
VAR
    bDone     : BOOL;
    nIdLoaded : UINT;
END_VAR

(* Neu laden, wenn sich die Kennung aendert (Inbetriebnahme) *)
IF bDone AND nMachineId <> nIdLoaded THEN bDone := FALSE; END_IF

IF NOT bDone THEN
    bDone := TRUE;
    nIdLoaded := nMachineId;
    bUnknownId := FALSE;
    CASE nMachineId OF
        1:  (* M1 *)
            stParams.nMachineId         := 1;
            stParams.sSwVersionExpected := '0.11.0';   (* Platzhalter, gleiche Quelle wie GVL_Config.sSwVersion: Pruefung wirkt erst mit externem Parametersatz *)
            stParams.eDriveVariant      := E_DriveVariant.Simulation;   (* [offen] bis Antriebsabbildung steht *)
            stParams.nNumAxes           := 4;
            stParams.nNumCncAxes        := 3;
            stParams.rSpindleMaxRpm     := 16600.0;
            stParams.rSpindleMinRpm     := 0.0;
            stParams.rSpindleVoltMax    := 10.0;
            stParams.tSpindleRunUp      := T#8S;
            stParams.tSpindleStandstill := T#10S;
            stParams.tHmiTimeout        := T#500MS;
            stParams.tFeedbackTimeout   := T#3S;
            stParams.bAirMonitoring     := TRUE;
            stParams.bHasToolChanger    := FALSE;
    ELSE
        bUnknownId := TRUE;
        stParams.nMachineId := 0;
    END_CASE
END_IF

bInvalid := bUnknownId OR stParams.rSpindleMaxRpm <= 0.0 OR stParams.rSpindleVoltMax <= 0.0
            OR stParams.tSpindleRunUp <= T#0S OR stParams.tSpindleStandstill <= T#0S
            OR stParams.tHmiTimeout <= T#0S OR stParams.tFeedbackTimeout <= T#0S
            OR stParams.rSpindleMinRpm < 0.0 OR stParams.rSpindleMinRpm >= stParams.rSpindleMaxRpm
            OR stParams.nNumAxes <> 4 OR stParams.nNumCncAxes <> 3
            OR stParams.eDriveVariant <> GVL_Config.eDriveVariant;
bLoaded := bDone AND NOT bInvalid;
END_FUNCTION_BLOCK
