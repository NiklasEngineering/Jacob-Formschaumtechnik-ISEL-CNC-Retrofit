{attribute 'qualified_only'}
(* Persistente Daten (Befunde 20 und 21). Ueberleben Neustart und Online-Change.
   nMachineId ist die Maschinenkennung des Geraets, gesetzt bei der Inbetriebnahme (0 = nicht gesetzt,
   Maschine bleibt gesperrt, Meldung 900). Damit laeuft ein Softwarestand auf allen Maschinen (LH-2.11.4).
   [offen] Schreibweg ueber die Service-Seite der HMI, bis dahin per ADS. *)
VAR_GLOBAL PERSISTENT
    nMachineId    : UINT;
    nOperatingSec : UDINT;            (* Betriebssekunden *)
    nSpindleSec   : UDINT;            (* Spindellaufzeit in Sekunden *)
    stJournal     : ST_HmiJournal;    (* Meldejournal *)
END_VAR
