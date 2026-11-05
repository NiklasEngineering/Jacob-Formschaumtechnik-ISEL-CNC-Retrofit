(* Variante A: CANopen DS402 ueber EL6751. NOCH NICHT IMPLEMENTIERT.
   Wartet auf: Bestaetigung iMD 40 im Interpolated Position Mode mit TwinCAT CNC,
   PDO-Zuordnung und Achsnummern (Schaltplan fehlt). Die Logik darf diesen Baustein
   nicht direkt kennen, nur ST_AxisDrive. *)
FUNCTION_BLOCK FB_AxisMap_Canopen
VAR_INPUT
    bSafeEnable : BOOL;
END_VAR
VAR_IN_OUT
    stAxis : ST_AxisDrive;
END_VAR

(* [offen] Zuordnung der Prozessdaten *)
stAxis.bReady   := FALSE;
stAxis.bEnabled := FALSE;
stAxis.bFault   := TRUE;
stAxis.nFaultCode := 16#FFFF0001;  (* nicht implementiert: Maschine bleibt gesperrt *)
END_FUNCTION_BLOCK
