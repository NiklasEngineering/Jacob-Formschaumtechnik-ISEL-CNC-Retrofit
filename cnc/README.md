# CNC-Parameter

`gemeinsam/` enthält Parameter, die für alle Maschinen gelten (Interpretereinstellungen, Look-Ahead-Grundwerte).
`M1/` bis `M4/` enthalten nur maschinenspezifische Werte (Achsdaten, Verfahrwege, Geschwindigkeiten, Gantry-Kopplung).

**Stand:** leer. Die CNC-Kanal- und Achsparameter lassen sich in TwinCAT CNC (TF5200) erst anlegen,
wenn ein XAE-Projekt mit CNC-Konfiguration auf dem Laptop vorliegt. Ob das per Automation Interface/MCP
möglich ist, ist offen (siehe Empfehlung 28.10.2026). Hier liegen später die exportierten Parameterlisten
im Textformat, damit Änderungen im Git nachvollziehbar sind.

Die Achsgeometrie von M1 (Gantry mit zwei Motoren, Querachse, Z) steht vorläufig in `config/M1.json`.
