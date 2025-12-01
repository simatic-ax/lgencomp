# LGenComp_CompensationStatus

| Constant | Value | Description |
|-----------|------|-------------|
| STATUS_NO_CALL | WORD#16#7000 | No job being currently processed |
| STATUS_FIRST_CALL | WORD#16#7001 | First call after incoming new job (rising edge 'enable') |
| STATUS_SUBSEQUENT_CALL | WORD#16#7002 | Subsequent call during active processing without further details |
| ERR_NO_ENC | WORD#16#8200 | Initialization error: Encoder not present |
| ERR_INVALID_ENC | WORD#16#8201 | Initialization error: Encoder number invalid |
| ERR_MOUNTING_MODE | WORD#16#8202 | Initialization error: Encoder mounting mode invalid |
| ERR_NULL_REFERENCE | WORD#16#8400 | Axis reference is NULL |
| ERR_UNDEFINED_STATE | WORD#16#8600 | Error due to an undefined state in state machine |
