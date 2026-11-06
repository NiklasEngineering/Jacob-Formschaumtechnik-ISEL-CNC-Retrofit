{attribute 'qualified_only'}
{attribute 'strict'}
(* Generische Achsschnittstelle. Variante A: CANopen DS402 ueber EL6751 (Interpolated Position
   unbestaetigt), Variante B: +-10 V Analog + Encoder-Klemmen (Rueckfall). *)
TYPE E_DriveVariant :
(
    CanopenDs402 := 0,
    AnalogEncoder := 1,
    Simulation := 2
) INT;
END_TYPE
