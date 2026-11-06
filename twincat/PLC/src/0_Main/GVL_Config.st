(* Build-Konfiguration (Befund 9). Die Antriebsabbildung wird hier gewaehlt. Solange nur das
   Simulationsabbild fertig ist, laeuft die Maschine nur damit. Fuer jede andere Variante bleibt die
   Maschine gesperrt (FB_AxisMap_Canopen meldet Fehler FFFF0001), bis die echte Abbildung existiert.
   Auf einer realen Maschine darf bSimulationBuild nicht TRUE sein. *)
VAR_GLOBAL CONSTANT
    eDriveVariant   : E_DriveVariant := E_DriveVariant.Simulation;
    bSimulationBuild: BOOL := TRUE;
    sSwVersion      : STRING(15) := '0.1.0';
    (* Befund 20: Maschinenkennung kommt aus GVL_Persistent.nMachineId, nicht aus dem Code.
       Nur im Simulationsbuild gilt bei nicht gesetzter Kennung (0) die Kennung 1 [Annahme]. *)
    nMachineIdSimDefault : UINT := 1;
    (* Achsnummerierung zentral (Befund 16). HMI- und CNC-Achse: 1 = X, 2 = Y, 3 = Z [Annahme CNC-Kanal].
       Referenzgruppe: 1 = Z, 2 = X, 3 = Y. Antrieb: 1 = Y1, 2 = Y2, 3 = X, 4 = Z [Annahme]. *)
    aHmiAxisToGroup  : ARRAY[1..3] OF USINT := [2, 3, 1];
    aGroupToHmiAxis  : ARRAY[1..3] OF USINT := [3, 1, 2];
    aDriveToHmiAxis  : ARRAY[1..4] OF USINT := [2, 2, 1, 3];
    aDriveToGroup    : ARRAY[1..4] OF USINT := [3, 3, 2, 1];
    (* Befund 15: Verzoegerung der Reglerabschaltung bei R4, damit die CNC gefuehrt bremst [Annahme] *)
    tR4DriveOffDelay : TIME := T#500MS;
END_VAR
