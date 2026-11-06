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
    nLimit  : UINT := 25;      (* wirksame Inbetriebnahme-Begrenzung in %, nach dem Anlauf immer 25 *)
    rtWcsWrite : R_TRIG;
END_VAR

rtLoad(CLK := stCmd.bProgramLoad);
rtWrite(CLK := stCmd.bTableWrite);
rtWcs(CLK := stCmd.bWcsSetCurrent);

(* Overrides begrenzen, die SPS entscheidet *)
(* Inbetriebnahme-Begrenzung: Absenken sofort, Anheben nur im Stillstand, immer 1..100 % *)
IF stCmd.nSpeedLimitPct < 1 THEN
    nLimit := 1;
ELSIF stCmd.nSpeedLimitPct < nLimit THEN
    nLimit := MIN(stCmd.nSpeedLimitPct, 100);
ELSIF stCmd.nSpeedLimitPct > nLimit AND bStandstill THEN
    nLimit := MIN(stCmd.nSpeedLimitPct, 100);
END_IF
stSts.nSpeedLimitActivePct := nLimit;

stSts.nOvrFeed    := MIN(stCmd.nOvrFeed, 120) * nLimit / 100;
stSts.nOvrRapid   := MIN(stCmd.nOvrRapid, 100) * nLimit / 100;
stSts.nOvrSpindle := LIMIT(50, stCmd.nOvrSpindle, 120);

rtWcsWrite(CLK := stCmd.bWcsTableWrite);
IF rtLoad.Q OR rtWrite.Q OR rtWcs.Q OR rtWcsWrite.Q THEN
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

(* G-16: Werkzeugtabelle und Nullpunkte haben getrennte Schreibimpulse, damit das Speichern der Werkzeuge
   nie die Nullpunkte ueberschreibt *)
IF rtWrite.Q THEN
    IF bStandstill THEN
        stSts.aTool := stCmd.aTool;
        stSts.bTableWriteOk := TRUE;
    ELSE
        stSts.bTableWriteRejected := TRUE;
    END_IF
END_IF

IF rtWcsWrite.Q THEN
    IF bStandstill THEN
        stSts.aWcs := stCmd.aWcs;
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
