(* Betriebsartenwahl. Wechsel nur im Stillstand (kein Programm, keine Achsbewegung, Spindel steht).
   Ein vorhandener Schluesselschalter (bKeyAuto) hat Vorrang vor der HMI. *)
FUNCTION_BLOCK FB_OpModeManager
VAR_INPUT
    eRequest       : E_OpMode;     (* von der HMI *)
    bStandstill    : BOOL;         (* alle Achsen stehen, Programm nicht aktiv, Spindel steht *)
    bHasKeySwitch  : BOOL;         (* [offen] Schluesselschalter am Pult vorhanden? *)
    bKeyAuto       : BOOL;         (* Schluesselschalter in AUTO *)
END_VAR
VAR_OUTPUT
    eMode          : E_OpMode;
    bChangeBlocked : BOOL;         (* Wunsch abgelehnt, HMI zeigt Hinweis *)
END_VAR

bChangeBlocked := FALSE;

IF bHasKeySwitch AND NOT bKeyAuto AND eRequest = E_OpMode.Auto THEN
    (* Schluessel nicht auf AUTO: Automatik nicht zulaessig *)
    bChangeBlocked := TRUE;
ELSIF eRequest <> eMode THEN
    IF bStandstill THEN
        eMode := eRequest;
    ELSE
        bChangeBlocked := TRUE;
    END_IF
END_IF

(* Schluessel weg von AUTO: sofort zurueck in Hand, sobald Stillstand *)
IF bHasKeySwitch AND NOT bKeyAuto AND eMode = E_OpMode.Auto AND bStandstill THEN
    eMode := E_OpMode.Hand;
END_IF
END_FUNCTION_BLOCK
