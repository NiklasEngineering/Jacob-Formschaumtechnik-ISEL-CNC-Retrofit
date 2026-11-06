VAR_GLOBAL
    stCmd : ST_HmiCmd;     (* HMI -> SPS *)
    stSts : ST_HmiSts;     (* SPS -> HMI *)
    stJournal : ST_HmiJournal;  (* SPS -> HMI, Meldejournal (Befund 21), Kopie von GVL_Persistent.stJournal *)
END_VAR
