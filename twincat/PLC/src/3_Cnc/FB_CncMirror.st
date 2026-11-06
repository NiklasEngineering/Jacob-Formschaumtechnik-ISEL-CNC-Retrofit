(* CNC-Spiegel fuer die HMI (GVL_HmiCnc). Solange TF5200/TF5310 fehlen, arbeitet er als Simulation:
   Overrides werden begrenzt, Programm laden und Tabellen schreiben nur im Stillstand,
   sonst bTableWriteRejected. Spaeter speist die CNC (Tc2_CncHli) dieselben Felder. Positionen bleiben
   in der Simulation stehen (keine Bewegung). Befund 23. *)
FUNCTION_BLOCK FB_CncMirror
VAR_INPUT
    bStandstill : BOOL;      (* kein Programm aktiv, kein Halt *)
END_VAR
VAR_IN_OUT
    stCmd : ST_HmiCncCmd;
    stSts : ST_HmiCncSts;
END_VAR
VAR
    rtLoad  : R_TRIG;
    rtWrite : R_TRIG;
    rtWcs   : R_TRIG;
    nIdx    : INT;
END_VAR

rtLoad(CLK := stCmd.bProgramLoad);
rtWrite(CLK := stCmd.bTableWrite);
rtWcs(CLK := stCmd.bWcsSetCurrent);

(* Overrides begrenzen, die SPS entscheidet *)
stSts.nOvrFeed    := MIN(stCmd.nOvrFeed, 120);
stSts.nOvrRapid   := MIN(stCmd.nOvrRapid, 100);
stSts.nOvrSpindle := LIMIT(50, stCmd.nOvrSpindle, 120);

IF rtLoad.Q OR rtWrite.Q OR rtWcs.Q THEN
    stSts.bTableWriteOk := FALSE;
    stSts.bTableWriteRejected := FALSE;
END_IF

IF rtLoad.Q THEN
    IF bStandstill THEN
        stSts.sProgramName := stCmd.sProgramSelect;
        stSts.bProgramLoaded := stCmd.sProgramSelect <> '';
        stSts.bTableWriteOk := TRUE;
    ELSE
        stSts.bTableWriteRejected := TRUE;
    END_IF
END_IF

IF rtWrite.Q THEN
    IF bStandstill THEN
        stSts.aTool := stCmd.aTool;
        stSts.aWcs  := stCmd.aWcs;
        stSts.bTableWriteOk := TRUE;
    ELSE
        stSts.bTableWriteRejected := TRUE;
    END_IF
END_IF

IF rtWcs.Q THEN
    nIdx := UINT_TO_INT(stSts.nActWcs);
    IF bStandstill AND nIdx >= 54 AND nIdx <= 59 THEN
        stSts.aWcs[nIdx].rX := stSts.aAxis[1].rActPosMach;
        stSts.aWcs[nIdx].rY := stSts.aAxis[2].rActPosMach;
        stSts.aWcs[nIdx].rZ := stSts.aAxis[3].rActPosMach;
        stCmd.aWcs[nIdx] := stSts.aWcs[nIdx];
        stSts.bTableWriteOk := TRUE;
    ELSE
        stSts.bTableWriteRejected := TRUE;
    END_IF
END_IF
END_FUNCTION_BLOCK
