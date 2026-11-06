(* SPS -> HMI. CNC-Werte (Achspositionen, Overrides, Werkzeug-/Nullpunkttabelle) liefert der
   CNC-Spiegel GVL_HmiCnc (ST_HmiCncSts), solange TF5310 nicht verfuegbar ist. *)
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
    bHandwheelActive: BOOL;
    eHomeState      : ARRAY[1..3] OF E_HomeState;
    nHomeStep       : USINT;
    aAlarms         : ARRAY[0..14] OF ST_Alarm;    (* Index = E_AlarmSlot *)
    aDrive          : ARRAY[1..4] OF ST_AxisDrive; (* Diagnose, 1=Y1 2=Y2 3=X 4=Z [Annahme] *)
    bFieldbusOk     : BOOL;
    bFuFault        : BOOL;    (* Rohsignal *)
    bPtcTrip        : BOOL;    (* Rohsignal *)
    bSimulationActive : BOOL;  (* Simulationsabbild der Antriebe aktiv, nie auf einer realen Maschine *)
    bModeChangeBlocked: BOOL;  (* Betriebsartenwunsch abgelehnt *)
    nHeartbeatEcho  : UINT;    (* Rueckspiegel stCmd.nHeartbeat, Befund 16 *)
    bLimitFreeRun   : BOOL;    (* Endschalter angefahren, Freifahren in Hand im Schleichgang moeglich, Befund 15 *)
END_STRUCT
END_TYPE
