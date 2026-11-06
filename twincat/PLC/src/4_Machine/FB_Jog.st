(* Tippbetrieb aus der HMI (Anforderungen 2.3.1 und 2.3.2). Nur mit Lebenszeichen der HMI, nur
   in Betriebsart Hand. Befund 6 der Papierpruefung: Tippen startet nur mit einer steigenden Flanke
   der Taste, waehrend alle Freigaben bestehen. Eine beim Wiederkehren der Freigabe (Quittierung,
   Sicherheitskreis, HMI-Lebenszeichen) noch gehaltene Taste startet nichts. Die Achsnummer wird
   beim Start festgehalten. Die Bewegung selbst fordert die CNC an. *)
FUNCTION_BLOCK FB_Jog
VAR_INPUT
    bJogOk       : BOOL;      (* aus FB_Interlocks *)
    bPlus        : BOOL;
    bMinus       : BOOL;
    nAxis        : USINT;     (* 1=X, 2=Y, 3=Z *)
    bRapid       : BOOL;
    nHeartbeat   : UINT;
    tHmiTimeout  : TIME;
    bPlusBlocked  : BOOL;     (* G-01: Endschalter Plus-Seite der gewaehlten Achse ausgeloest, Tippen+ gesperrt *)
    bMinusBlocked : BOOL;     (* Minus-Seite ausgeloest, Tippen- gesperrt *)
END_VAR
VAR_OUTPUT
    bJogPlusReq  : BOOL;
    bJogMinusReq : BOOL;
    nAxisReq     : USINT;
    bRapidReq    : BOOL;
    bHmiLinkOk   : BOOL;
END_VAR
VAR
    nLastHb   : UINT;
    tonLink   : TON;
    rtPlus    : R_TRIG;
    rtMinus   : R_TRIG;
    bActPlus  : BOOL;
    bActMinus : BOOL;
    nAxisLatch: USINT;
    bOkNow    : BOOL;
    nAxisPrev : USINT;
    nStableCyc: USINT;        (* Zyklen, seit denen nAxis unveraendert ist (Befund 16) *)
    bPendPlus : BOOL;         (* Flanke gesehen, wartet auf stabile Achsnummer *)
    bPendMinus: BOOL;
END_VAR

(* Lebenszeichen: Aenderung innerhalb tHmiTimeout *)
IF nHeartbeat <> nLastHb THEN
    nLastHb := nHeartbeat;
    tonLink(IN := FALSE);
END_IF
tonLink(IN := TRUE, PT := tHmiTimeout);
bHmiLinkOk := NOT tonLink.Q AND tHmiTimeout > T#0S;

rtPlus(CLK := bPlus);
rtMinus(CLK := bMinus);
bOkNow := bJogOk AND bHmiLinkOk AND nAxis >= 1 AND nAxis <= 3;

(* Befund 16: Achsnummer und Taste kommen als getrennte ADS-Schreibzugriffe. Start erst, wenn nAxis
   mindestens 2 Zyklen stabil ist; Achswechsel waehrend der Fahrt stoppt sofort. *)
IF nAxis <> nAxisPrev THEN
    nAxisPrev := nAxis; nStableCyc := 0;
ELSIF nStableCyc < 255 THEN
    nStableCyc := nStableCyc + 1;
END_IF

IF NOT bOkNow THEN
    bActPlus := FALSE; bActMinus := FALSE; bPendPlus := FALSE; bPendMinus := FALSE;
ELSE
    (* G-01: Ausgeloester Endschalter beendet das Tippen in dieser Richtung sofort, neue Flanke noetig *)
    IF bPlusBlocked  THEN bActPlus  := FALSE; bPendPlus  := FALSE; END_IF
    IF bMinusBlocked THEN bActMinus := FALSE; bPendMinus := FALSE; END_IF
    IF NOT bPlus  OR bMinus THEN bActPlus  := FALSE; bPendPlus  := FALSE; END_IF
    IF NOT bMinus OR bPlus  THEN bActMinus := FALSE; bPendMinus := FALSE; END_IF
    IF (bActPlus OR bActMinus) AND nAxis <> nAxisLatch THEN
        bActPlus := FALSE; bActMinus := FALSE;
    END_IF
    IF rtPlus.Q  AND NOT bMinus THEN bPendPlus  := TRUE; END_IF
    IF rtMinus.Q AND NOT bPlus  THEN bPendMinus := TRUE; END_IF
    IF bPendPlus AND nStableCyc >= 2 AND NOT bActMinus AND NOT bPlusBlocked THEN
        bActPlus := TRUE; bPendPlus := FALSE; nAxisLatch := nAxis;
    END_IF
    IF bPendMinus AND nStableCyc >= 2 AND NOT bActPlus AND NOT bMinusBlocked THEN
        bActMinus := TRUE; bPendMinus := FALSE; nAxisLatch := nAxis;
    END_IF
END_IF

bJogPlusReq  := bActPlus;
bJogMinusReq := bActMinus;
nAxisReq     := nAxisLatch;
bRapidReq    := bRapid AND (bActPlus OR bActMinus);
END_FUNCTION_BLOCK
