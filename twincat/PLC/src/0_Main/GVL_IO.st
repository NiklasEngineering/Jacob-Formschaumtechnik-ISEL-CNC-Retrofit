(* Prozessabbild der Maschine. Die Verknuepfung mit den Klemmen erfolgt erst nach
   Klemmenwahl und Schaltplan, bis dahin gibt es hier nur Variablen ohne Adresse (Simulation).
   Ruhestrom: FALSE = Fehler/ausgeloest bei allen Sicherheits- und Endschaltersignalen. *)
VAR_GLOBAL
    (* Eingaenge *)
    bSafetyRelayFeedback : BOOL;   (* Pilz-Relais Rueckmeldung *)
    bDoorClosed          : BOOL;
    bAirOk               : BOOL;
    bExtractionOk        : BOOL;
    bFuReady             : BOOL;   (* Commander SK bereit *)
    bFuAtSpeed           : BOOL;   (* [Annahme] Drehzahl erreicht *)
    bSpindlePtcOk        : BOOL;
    bKeyAuto             : BOOL;   (* [offen] nur falls Schluesselschalter vorhanden *)
    bFieldbusOk          : BOOL;   (* EtherCAT/CANopen Status *)
    (* Ausgaenge *)
    bSpindleRun          : BOOL;
    bSpindleCcw          : BOOL;
    rSpindleVolt         : REAL;   (* EL4002 Kanal 1, 0..10 V *)
    bExtractionOut       : BOOL;
    bBlowAirOut          : BOOL;
    bVacuumOut           : BOOL;
    (* Achsen, vier Stueck: 1=Y1 Portal links, 2=Y2 Portal rechts, 3=X Quer, 4=Z [Annahme] *)
    aAxis                : ARRAY[1..4] OF ST_AxisDrive;
    (* Einspeisung fuer Simulation und Test (wirkt nur im Simulationsabbild FB_AxisMap_Simulation) *)
    aSimLimitPlus  : ARRAY[1..4] OF BOOL;
    aSimLimitMinus : ARRAY[1..4] OF BOOL;
    aSimFault      : ARRAY[1..4] OF BOOL;
END_VAR
