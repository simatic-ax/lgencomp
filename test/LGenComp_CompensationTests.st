USING AxUnit;
USING Siemens.Simatic.MemoryAccess;
USING Siemens.Simatic.MotionControl.Native;
USING Simatic.Ax.LGenComp;

NAMESPACE Simatic.Ax.LgenComp.Tests

    {TestFixture}
    CLASS LGenComp_CompensationTests

        VAR PRIVATE
            instCompensation : LGenComp_Compensation;
            sensor : LGenComp_typeSensorAddressIn;
        END_VAR

        {Test}
        METHOD PUBLIC TestReadMemoryMock
            VAR_TEMP
                result : DWORD;
            END_VAR

            Mocking.Mock(NAME_OF(Siemens.Simatic.MemoryAccess.ReadMemory), NAME_OF(ReadMemoryMock));
            ReadMemory(sensor.area, sensor.offset, result);
            Assert.Equal(expected := DWORD#16#12345678, actual := result);
        END_METHOD

        {Test}
        METHOD PUBLIC TestWriteMemoryMock
            VAR_TEMP
                value : DWORD := DWORD#16#4321_9876;
            END_VAR

            Mocking.Mock(NAME_OF(Siemens.Simatic.MemoryAccess.WriteMemory), NAME_OF(WriteMemoryMock));
            WriteMemory(sensor.area, sensor.offset, value);
            Assert.Equal(expected := DWORD#16#4321_9876, actual := value);
        END_METHOD
        {Test}
        METHOD PUBLIC TestInitialState
            // Verify initial state before enable
            Assert.Equal(expected := FALSE, actual := instCompensation.valid);
            Assert.Equal(expected := FALSE, actual := instCompensation.busy);
            Assert.Equal(expected := FALSE, actual := instCompensation.error);
            Assert.Equal(expected := LGenComp_CompensationStatus#STATUS_NO_CALL, actual := instCompensation.status);
        END_METHOD

        {Test}
        METHOD PUBLIC TestOutputsBeforeEnable
            // Verify all outputs are FALSE/zero before enable
            Assert.Equal(expected := UDINT#0, actual := instCompensation.encoderIncrements);
            Assert.Equal(expected := LREAL#0.0, actual := instCompensation.encoderPosition);
            Assert.Equal(expected := DINT#0, actual := instCompensation.compensationIncrements);
        END_METHOD

    END_CLASS



    FUNCTION ReadMemoryMock : BOOL
        VAR_INPUT
            area : Siemens.Simatic.MemoryAccess.ReadArea;
            byteOffset : DINT;
        END_VAR
        VAR_OUTPUT
            value : DWORD;
        END_VAR
        value := DWORD#16#1234_5678;
        ReadMemoryMock := TRUE;
    END_FUNCTION

    FUNCTION WriteMemoryMock
        VAR_INPUT
            area : Siemens.Simatic.MemoryAccess.WriteArea;
            byteOffset : DINT;
            value : DWORD;
        END_VAR
        ;
    END_FUNCTION
END_NAMESPACE
