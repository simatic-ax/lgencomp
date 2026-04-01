NAMESPACE Simatic.Ax.LGenComp
    TYPE
        CompensationStatus : WORD (
            /// No job being currently processed
            STATUS_NO_CALL := WORD#16#7000,
            /// First call after incoming new job (rising edge 'execute')
            STATUS_FIRST_CALL := WORD#16#7001,
            /// Subsequent call during active processing without further details
            STATUS_SUBSEQUENT_CALL := WORD#16#7002,
            /// Initialization error: Encoder number invalid
            ERR_NO_ENC := WORD#16#8200,
            /// Initialization error: Encoder not present
            ERR_INVALID_ENC := WORD#16#8201,
            /// Initialization error: Encoder mounting mode invalid
            ERR_MOUNTING_MODE := WORD#16#8203,
            /// Axis reference is NULL
            ERR_NULL_REFERENCE := WORD#16#8400,
            /// Error due to an undefined state in state machine
            ERR_UNDEFINED_STATE := WORD#16#8600
            ) := STATUS_NO_CALL;
    END_TYPE
END_NAMESPACE