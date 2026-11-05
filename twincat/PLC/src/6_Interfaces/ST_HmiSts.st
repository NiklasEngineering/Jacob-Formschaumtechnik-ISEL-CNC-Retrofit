(* SPS -> HMI. CNC-Werte (Achspositionen, Overrides, Werkzeug-/Nullpunkttabelle) liest die HMI
   direkt aus der CNC (TF5310 Datenmodell), nicht ueber diese Struktur. *)
TYPE ST_HmiSts :
STRUCT
    eMode           : E_OpMode;
    eState          : E_MachState;
    bSafetyOk       : BOOL;
    bDrivesEnabled  : BOOL;
    bAllHomed       : BOOL;
    bHmiLinkOk      : BOOL;    (* Heartbeat der HMI wird ueberwacht *)
    bSpindleRunning : BOOL;
    rSpindleActRpm  : REAL;
    bExtractionOn   : BOOL;
    bBlowAirOn      : BOOL;
    bVacuumOn       : BOOL;
    bToolChangeReq  : BOOL;    (* Aufforderung am Panel *)
    nToolChangeNo   : UINT;
    nTopAlarmId     : INT;     (* hoechste aktive Meldung, 0 = keine *)
    eTopAlarmClass  : E_FaultClass;
    nActiveAlarms   : UINT;
    nMachineId      : UINT;    (* aus Maschinenparametern, z. B. 1 fuer M1 *)
    sSwVersion      : STRING(15);
    dwOperatingSec  : UDINT;   (* Betriebssekunden, fuer Wartungsanzeige *)
    dwSpindleSec    : UDINT;
END_STRUCT
END_TYPE
