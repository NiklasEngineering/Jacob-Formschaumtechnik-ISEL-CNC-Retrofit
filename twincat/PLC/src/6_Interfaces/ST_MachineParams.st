(* Maschinenparameter. Je Maschine eine Datei in config/, geladen beim Start.
   Werte in config/M1.json mit [Annahme] gekennzeichnet, solange nicht bestaetigt. *)
TYPE ST_MachineParams :
STRUCT
    nMachineId        : UINT;
    sSwVersionExpected: STRING(15);
    eDriveVariant     : E_DriveVariant;    (* muss zur Build-Konfiguration passen (Befund 20) *)
    nNumAxes          : USINT;             (* Antriebe ohne Spindel: Y1, Y2, X, Z = 4 *)
    nNumCncAxes       : USINT;             (* CNC-/HMI-Achsen X, Y, Z = 3 (Y als Gantry) *)
    rSpindleMaxRpm    : REAL;              (* 16600 fuer VKH63/26-90T *)
    rSpindleMinRpm    : REAL;
    rSpindleVoltMax   : REAL;              (* 10.0 V entspricht rSpindleMaxRpm *)
    tSpindleRunUp     : TIME;              (* Wartezeit nach Start bis Drehzahl erreicht *)
    tSpindleStandstill: TIME;              (* Auslaufzeit bis Stillstand gemeldet *)
    tHmiTimeout       : TIME;              (* Heartbeat-Ausfall -> Tippen stoppt *)
    tFeedbackTimeout  : TIME;              (* Rueckmeldung Ventil/Spindel *)
    bAirMonitoring    : BOOL;
    bHasToolChanger   : BOOL;
END_STRUCT
END_TYPE
