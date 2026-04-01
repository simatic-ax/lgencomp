USING Siemens.Simatic.MemoryAccess;
USING Siemens.Simatic.MotionControl.Native;
USING System.Math;
NAMESPACE Simatic.Ax.LGenComp
    ///================================================================================
    /// SIEMENS AG
    /// (c)Copyright 2026 All Rights Reserved
    ///--------------------------------------------------------------------------------
    /// Library:       LGenComp
    /// Engineering:   SIMATIC AX
    /// Requirements:  Needs to be called in the Task MC_PreServo
    /// Functionality: Compensates an axis position by a compensation value via encoder increment adjustment.
    ///================================================================================
    FUNCTION_BLOCK Compensation
        VAR_INPUT
            /// TRUE: Enable functionality of FB
            enable : BOOL;
            /// Technology object, also supports TO_SynchronousAxis
            axis  : REF_TO TO_PositioningAxis;
            /// Compensation value
            compensationValue : LREAL;
            /// Encoder number (1..4)  for which the compensation is performed. Default: 1
            encoderNumber : UINT := UINT#1;
            /// Byte offset of G1_XIST1 in PROFIdrive telegrams. Default: 12 for TEL105
            encoderOffsetG1_XIST1 : UINT := UINT#12;
            /// Number of cycles until full compensation value is active
            activationCycles : UINT := UINT#1000;
        END_VAR

        VAR_OUTPUT
            /// Encoder value without compensation
            encoderIncrements : UDINT;
            /// Encoder position without compensation
            encoderPosition : LREAL;
            /// Additional encoder increments based on compensation
            compensationIncrements : DINT;
            /// TRUE: Valid set of output values available at the FB
            valid  : BOOL;
            /// TRUE: FB is not finished and new output values can be expected
            busy  : BOOL;
            /// TRUE: An error occurred during the execution of the FB
            error  : BOOL;
            /// 16#0000 - 16#7FFF: Status of the FB, 16#8000 - 16#FFFF: Error identification
            status  : CompensationStatus := CompensationStatus#STATUS_NO_CALL;
        END_VAR

        VAR
            _encoderIncrements : UDINT;           // Raw encoder value without compensation applied
            _encoderPosition : LREAL;             // Encoder position without compensation
            _compensationIncrements : DINT;       // Calculated compensation in encoder increments
            _encNo : UINT;                        // Currently configured encoder number
            _compValue : LREAL;                   // Current compensation value (ramped during activation/deactivation)
            _compIncrementValue : LREAL;          // Compensation value converted to encoder increments
            _factorIncrements : LREAL;            // Conversion factor from position units to encoder increments
            _g1_XIST1 : DWORD;                    // PROFIdrive G1_XIST1 encoder value from telegram
            _activationCycles : UINT;             // Configured number of cycles for gradual activation
            _rampCycles : UINT;                   // Target cycle count for ramping calculations
            _enableOld  : BOOL;                   // Old value of 'enable' input for edge detection
            _valid  : BOOL;                       // Static value for output 'valid'
            _busy  : BOOL;                        // Static value for output 'busy'
            _error  : BOOL;                       // Static value for output 'error'
            _errorUserCleared  : BOOL;            // Error occurred that can only be solved by user; rising edge at enable input necessary
            _status  : CompensationStatus := CompensationStatus#STATUS_NO_CALL;   // Static value for output 'status'
            _fbState  : DINT := NO_PROCESSING;    // State in the state machine of the FB
            _disablingCompleted  : BOOL;          // TRUE: Disabling has been completed
            _cycleCounter  : UINT;                // Current cycle count for ramping compensation (0 to _rampCycles)
            _sensorAddressIn : typeSensorAddressIn;  // Memory address for encoder telegram data
            _axis : REF_TO TO_PositioningAxis;    // Stored axis reference
            _readResult : BOOL;                   // Result of ReadMemory operation
        END_VAR

        VAR_TEMP
            tempEnable : BOOL;                       // Temporary value for input 'enable'
            tempStepsPerRevolutionG1_XIST1 : LREAL;  // Encoder steps per revolution including fine resolution
            tempUnitsPerRevolution : LREAL;          // Units per revolution (degrees for rotary, mm for linear)
        END_VAR

        VAR CONSTANT
            ROTARY_AXIS : INT := 1;                  // Constant identifying rotary axis type
            MOUNTING_MOTOR_SHAFT : DINT := DINT#0;   // Encoder mounted on motor shaft
            MOUNTING_LOAD_SIDE : DINT := DINT#1;     // Encoder mounted on load side
            MOUNTING_EXT_MEAS_SYS: DINT := DINT#2;   // External measuring system
            NO_PROCESSING : DINT := DINT#0;          // State: No processing active
            ENABLING : DINT := DINT#10;              // State: Enabling and initializing
            PROCESSING : DINT := DINT#50;            // State: Active compensation
            DISABLING : DINT := DINT#90;             // State: Gradual deactivation
            ERR : DINT := DINT#200;                  // State: Error occurred
        END_VAR

        // Create process image of enable input
        tempEnable := enable;

        // ============================================================================
        // ENABLING/DISABLING LOGIC
        // ============================================================================

        // Rising edge on enable input: Start function block
        IF (tempEnable = TRUE) AND NOT _enableOld AND (_status = CompensationStatus#STATUS_NO_CALL) THEN
            // Validate axis reference FIRST before any initialization
            IF axis = NULL THEN
                // Error: Invalid axis reference
                _errorUserCleared := TRUE;
                _valid := FALSE;
                _busy := FALSE;
                _status := CompensationStatus#ERR_NULL_REFERENCE;
                _fBState := ERR;
                RETURN;
            ELSE
                // Store valid axis reference
                _axis := axis;
            END_IF;

            // Initialize function block for first execution
            _valid := TRUE;
            _busy := TRUE;
            _error := FALSE;
            _errorUserCleared := FALSE;
            _status := CompensationStatus#STATUS_FIRST_CALL;

            // Store activation ramp configuration
            _activationCycles := activationCycles;

            // Transition to ENABLING state
            _fBState := ENABLING;
            _disablingCompleted := FALSE;

        // Falling edge on enable input: Stop function block
        ELSIF (tempEnable = FALSE) AND (_enableOld = TRUE) THEN
            IF _fBState = PROCESSING THEN
                // Start gradual deactivation ramp
                _fBState := DISABLING;
            ELSE
                // Not in PROCESSING state, skip DISABLING and immediately complete
                _disablingCompleted := TRUE;
            END_IF;

        // Update status to SUBSEQUENT_CALL after initial cycle
        ELSIF (_status = CompensationStatus#STATUS_FIRST_CALL) THEN
            _status := CompensationStatus#STATUS_SUBSEQUENT_CALL;
        END_IF;

        // Store enable input for edge detection
        _enableOld := tempEnable;

        // Early exit if function block is not active
        IF (_status = CompensationStatus#STATUS_NO_CALL) THEN
            RETURN;
        END_IF;

        // ============================================================================
        // STATE MACHINE
        // ============================================================================

        CASE _fBState OF
            NO_PROCESSING:
                // No processing active - idle state
                ;

            ENABLING:
                // Validate and configure encoder, calculate conversion factors
                // Check if encoder number has changed from previous initialization
                IF encoderNumber <> _encNo THEN
                    _encNo := encoderNumber;

                    // Validate encoder number range (1-4)
                    IF _encNo < UINT#1 OR _encNo > UINT#4 THEN
                        _errorUserCleared := TRUE;
                        _valid := FALSE;
                        _encoderIncrements := UINT#0;
                        _status := CompensationStatus#ERR_INVALID_ENC;
                        _fBState := ERR;
                    // Check if encoder exists in axis configuration
                    ELSIF NOT _axis^.Sensor[_encNo].Existent THEN
                        _errorUserCleared := TRUE;
                        _valid := FALSE;
                        _encoderIncrements := UINT#0;
                        _status := CompensationStatus#ERR_NO_ENC;
                        _fBState := ERR;
                    END_IF;

                    // Get PROFIdrive telegram memory address for G1_XIST1 encoder value
                    _sensorAddressIn.area := _axis^.Sensor[_encNo]._Interface.AddressIn.AREA;
                    _sensorAddressIn.dbNumber := _axis^.Sensor[_encNo]._Interface.AddressIn.DB_NUMBER;
                    _sensorAddressIn.offset := TO_DINT(_axis^.Sensor[_encNo]._Interface.AddressIn.OFFSET / UDINT#8 + encoderOffsetG1_XIST1);

                    // Calculate conversion factor from position units to encoder increments
                    // Apply fine resolution scaling to base steps per revolution
                    tempStepsPerRevolutionG1_XIST1 := _axis^.Sensor[_encNo].Parameter.StepsPerRevolution
                                                       * (2.0 ** _axis^.Sensor[_encNo].Parameter.FineResolutionXist1);

                    // Invert if encoder or actor direction is inverted (XOR: only one inverted)
                    IF _axis^.Sensor[_encNo].InverseDirection XOR _axis^.Actor.InverseDirection THEN
                        tempStepsPerRevolutionG1_XIST1 := -1.0 * tempStepsPerRevolutionG1_XIST1;
                    END_IF;

                    // Determine units per revolution based on axis type
                    IF _axis^.Properties.MotionType = ROTARY_AXIS THEN
                        tempUnitsPerRevolution := 360.0;  // Degrees per revolution for rotary axis
                    ELSE
                        tempUnitsPerRevolution := _axis^.Mechanics.LeadScrew;  // mm per revolution for linear axis
                    END_IF;

                    // Calculate increment conversion factor based on encoder mounting configuration
                    CASE _axis^.Sensor[_encNo].MountingMode OF
                        MOUNTING_MOTOR_SHAFT:
                            // Motor shaft: Account for gear ratio between motor and load
                            _factorIncrements := tempStepsPerRevolutionG1_XIST1 / _axis^.LoadGear.Denominator
                                                  * _axis^.LoadGear.Numerator / tempUnitsPerRevolution;
                        MOUNTING_LOAD_SIDE:
                            // Load side: Direct conversion without gear ratio
                            _factorIncrements := tempStepsPerRevolutionG1_XIST1 / tempUnitsPerRevolution;
                        MOUNTING_EXT_MEAS_SYS:
                            // External measuring system: Use configured distance per revolution
                            _factorIncrements := tempStepsPerRevolutionG1_XIST1 / _axis^.Sensor[_encNo].Parameter.DistancePerRevolution;
                        ELSE
                            // Unsupported mounting mode
                            _errorUserCleared := TRUE;
                            _valid := FALSE;
                            _status := CompensationStatus#ERR_MOUNTING_MODE;
                            _fBState := ERR;
                    END_CASE;
                END_IF;

                // Initialize activation ramp cycle counter
                IF _activationCycles <> _rampCycles THEN
                    _rampCycles := Max(_activationCycles, UINT#1);
                END_IF;

                // Ramp up cycle counter for gradual compensation activation
                _cycleCounter := MIN(_cycleCounter + UINT#1, _rampCycles);

                // Transition to PROCESSING when ramp-up is complete
                IF (_cycleCounter = _rampCycles) THEN
                    _fBState := PROCESSING;
                END_IF;

            PROCESSING:
                // Active compensation state - compensation is fully applied
                ;

            DISABLING:
                // Gradual deactivation: Ramp down compensation over configured cycles
                _cycleCounter := Max(_cycleCounter - UINT#1, UINT#0);

                // Mark disabling as complete when ramp-down reaches zero
                IF _cycleCounter = UINT#0 THEN
                    _disablingCompleted := TRUE;
                END_IF;

            ERR:
                // Error state - no processing
                ;

            ELSE
                // Undefined state reached - set error
                _status := CompensationStatus#ERR_UNDEFINED_STATE;
                _errorUserCleared := TRUE;
        END_CASE;

        // ============================================================================
        // COMPENSATION PROCESSING
        // ============================================================================

        IF ((_fBState = ENABLING) OR (_fBState = PROCESSING) OR (_fBState = DISABLING)) THEN
            // Read actual encoder value from PROFIdrive telegram memory
            _readResult := ReadMemory(_sensorAddressIn.area, _sensorAddressIn.offset, _g1_XIST1);

            // Calculate uncompensated encoder position
            _encoderPosition := _axis^.StatusSensor[_encNo].Position - _compValue;
            _encoderIncrements := TO_UDINT(_g1_XIST1);

            // Calculate ramped compensation value (0% to 100% during ENABLING, 100% to 0% during DISABLING)
            _compValue := compensationValue * _cycleCounter / _rampCycles;

            IF _compValue <> 0.0 THEN
                // Convert compensation from position units to encoder increments
                _compIncrementValue := _compValue * _factorIncrements;
                _compensationIncrements := TO_DINT(_compIncrementValue);

                // Apply compensation by modifying encoder value
                _g1_XIST1 := TO_DWORD(TO_DINT(_g1_XIST1) + _compensationIncrements);

                // Write compensated value back to PROFIdrive telegram memory
                // Note: WriteMemory in SIMATIC AX doesn't return status via ENO
                WriteMemory(_sensorAddressIn.area, _sensorAddressIn.offset, _g1_XIST1);
            ELSE
                _compensationIncrements := 0;
            END_IF;
        END_IF;

        // ============================================================================
        // OUTPUT HANDLING
        // ============================================================================

        IF (_disablingCompleted = TRUE) THEN
            // Reset all outputs and state after successful disabling
            _valid := FALSE;
            _busy := FALSE;
            _error := FALSE;
            _errorUserCleared := FALSE;
            _status := CompensationStatus#STATUS_NO_CALL;
            _fBState := NO_PROCESSING;
            _axis := NULL;

        ELSIF (_errorUserCleared = TRUE) AND (_error = FALSE) THEN
            // Error state that requires user intervention (rising edge on enable to clear)
            _valid := FALSE;
            _busy := FALSE;
            _error := TRUE;
            _fBState := NO_PROCESSING;
        END_IF;

        // Copy internal _es to output variables
        status := _status;
        error := _error;
        busy := _busy;
        valid := _valid;

        encoderIncrements := _encoderIncrements;
        encoderPosition := _encoderPosition;
        compensationIncrements := _compensationIncrements;
    END_FUNCTION_BLOCK
END_NAMESPACE