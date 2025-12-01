USING AxUnit.Assert;
USING Simatic.Ax.LGenComp;

NAMESPACE Simatic.Ax.lgencomp.Tests
    {TestFixture}
    CLASS TestLGenCompGetCompensationValueLinear
        VAR
            testArray : ARRAY[0..4] OF LGenComp_typeCompensationElement;
            result : LREAL;
            status : LGenComp_GetCompensationValueStatus;
        END_VAR

        {TestSetup}
        METHOD PUBLIC Setup
            testArray[0].xValue := 0.0;
            testArray[1].xValue := 10.0;
            testArray[2].xValue := 20.0;
            testArray[3].xValue := 30.0;
            testArray[4].xValue := 40.0;

            testArray[0].yValue := 0.0;
            testArray[1].yValue := 5.0;
            testArray[2].yValue := 15.0;
            testArray[3].yValue := 20.0;
            testArray[4].yValue := 30.0;
        END_METHOD

        {Test}
        METHOD PUBLIC TestInterpolationAtTableStart
            // Test interpolation at the first point
            result := LGenComp_GetCompensationValueLinear(
                xValue := 0.0,
                compensationArray := testArray,
                status => status
            );

            Equal(actual := result, expected := 0.0);
            Equal(actual := status, expected := LGenComp_GetCompensationValueStatus#STATE_VALID);
        END_METHOD

        {Test}
        METHOD PUBLIC TestInterpolationAtTableEnd
            // Test interpolation at the last point
            result := LGenComp_GetCompensationValueLinear(
                xValue := 40.0,
                compensationArray := testArray,
                status => status
            );

            Equal(actual := result, expected := 30.0);
            Equal(actual := status, expected := LGenComp_GetCompensationValueStatus#STATE_VALID);
        END_METHOD

        {Test}
        METHOD PUBLIC TestInterpolationBetweenPoints
            // Test interpolation between first and second point
            // At x=5.0, should be halfway between y=0.0 and y=5.0 = 2.5
            result := LGenComp_GetCompensationValueLinear(
                xValue := 5.0,
                compensationArray := testArray,
                status => status
            );

            Equal(actual := result, expected := 2.5);
            Equal(actual := status, expected := LGenComp_GetCompensationValueStatus#STATE_VALID);
        END_METHOD

        {Test}
        METHOD PUBLIC TestInterpolationMidRange
            // Test interpolation in the middle of the table
            // At x=25.0, between x=20.0 (y=15.0) and x=30.0 (y=20.0)
            // Should be 15.0 + (20.0-15.0) * (25.0-20.0)/(30.0-20.0) = 15.0 + 2.5 = 17.5
            result := LGenComp_GetCompensationValueLinear(
                xValue := 25.0,
                compensationArray := testArray,
                status => status
            );

            Equal(actual := result, expected := 17.5);
            Equal(actual := status, expected := LGenComp_GetCompensationValueStatus#STATE_VALID);
        END_METHOD

        {Test}
        METHOD PUBLIC TestClampingBelowMinimum
            // Test clamping when x-value is below minimum
            result := LGenComp_GetCompensationValueLinear(
                xValue := -10.0,
                compensationArray := testArray,
                status => status
            );

            // Should clamp to minimum and return value at x=0.0
            Equal(actual := result, expected := 0.0);
            Equal(actual := status, expected := LGenComp_GetCompensationValueStatus#WAR_RANGE_CLAMPING_ACTIVE);
        END_METHOD

        {Test}
        METHOD PUBLIC TestClampingAboveMaximum
            // Test clamping when x-value is above maximum
            result := LGenComp_GetCompensationValueLinear(
                xValue := 50.0,
                compensationArray := testArray,
                status => status
            );

            // Should clamp to maximum and return value at x=40.0
            Equal(actual := result, expected := 30.0);
            Equal(actual := status, expected := LGenComp_GetCompensationValueStatus#WAR_RANGE_CLAMPING_ACTIVE);
        END_METHOD

        {Test}
        METHOD PUBLIC TestInverseTable
            VAR
                inverseArray : ARRAY[0..4] OF LGenComp_typeCompensationElement;
            END_VAR

            // Create a table with descending x-values
            // X: [40.0, 30.0, 20.0, 10.0, 0.0]
            // Y: [30.0, 20.0, 15.0, 5.0, 0.0]
            inverseArray[0].xValue := 40.0;
            inverseArray[1].xValue := 30.0;
            inverseArray[2].xValue := 20.0;
            inverseArray[3].xValue := 10.0;
            inverseArray[4].xValue := 0.0;

            inverseArray[0].yValue := 30.0;
            inverseArray[1].yValue := 20.0;
            inverseArray[2].yValue := 15.0;
            inverseArray[3].yValue := 5.0;
            inverseArray[4].yValue := 0.0;

            // Test interpolation in inverse table
            result := LGenComp_GetCompensationValueLinear(
                xValue := 25.0,
                compensationArray := inverseArray,
                status => status
            );

            // At x=25.0, between x=30.0 (y=20.0) and x=20.0 (y=15.0)
            // Should be 20.0 + (15.0-20.0) * (25.0-30.0)/(20.0-30.0) = 20.0 - 2.5 = 17.5
            Equal(actual := result, expected := 17.5);
            Equal(actual := status, expected := LGenComp_GetCompensationValueStatus#STATE_VALID);
        END_METHOD

        {Test}
        METHOD PUBLIC TestSingleSegmentTable
            VAR
                singleSegmentArray : ARRAY[0..1] of LGenComp_typeCompensationElement;
            END_VAR

            // Create a table with only 2 points (single segment)

            singleSegmentArray[0].xValue := 0.0;
            singleSegmentArray[1].xValue := 100.0;

            singleSegmentArray[0].yValue := 10.0;
            singleSegmentArray[1].yValue := 50.0;

            // Test interpolation at 50% (x=50.0)
            result := LGenComp_GetCompensationValueLinear(
                xValue := 50.0,
                compensationArray := singleSegmentArray,
                status => status
            );

            // Should be 10.0 + (50.0-10.0) * 0.5 = 30.0
            Equal(actual := result, expected := 30.0);
            Equal(actual := status, expected := LGenComp_GetCompensationValueStatus#STATE_VALID);
        END_METHOD

        {Test}
        METHOD PUBLIC TestNegativeValues
            VAR
                negativeArray : ARRAY[0..3] OF LGenComp_typeCompensationElement;
            END_VAR

            // Create a table with negative values
            negativeArray[0].xValue := -20.0;
            negativeArray[1].xValue := -10.0;
            negativeArray[2].xValue := 0.0;
            negativeArray[3].xValue := 10.0;

            negativeArray[0].yValue := -15.0;
            negativeArray[1].yValue := -5.0;
            negativeArray[2].yValue := 0.0;
            negativeArray[3].yValue := 10.0;


            // Test interpolation at x=-5.0 (between -10.0 and 0.0)
            result := LGenComp_GetCompensationValueLinear(
                xValue := -5.0,
                compensationArray := negativeArray,
                status => status
            );

            // Should be -5.0 + (0.0-(-5.0)) * (-5.0-(-10.0))/(0.0-(-10.0)) = -5.0 + 2.5 = -2.5
            Equal(actual := result, expected := -2.5);
            Equal(actual := status, expected := LGenComp_GetCompensationValueStatus#STATE_VALID);
        END_METHOD

        {Test}
        METHOD PUBLIC TestExactTablePoint
            // Test when x-value exactly matches a table point
            result := LGenComp_GetCompensationValueLinear(
                xValue := 20.0,
                compensationArray := testArray,
                status => status
            );

            Equal(actual := result, expected := 15.0);
            Equal(actual := status, expected := LGenComp_GetCompensationValueStatus#STATE_VALID);
        END_METHOD

        {Test}
        METHOD PUBLIC TestVerySmallInterval
            VAR
                smallIntervalArray : ARRAY[0..2] OF LGenComp_typeCompensationElement;
            END_VAR

            // Create a table with very small x-intervals
            smallIntervalArray[0].xValue := 0.0;
            smallIntervalArray[1].xValue := 0.001;
            smallIntervalArray[2].xValue := 0.002;

            smallIntervalArray[0].yValue := 0.0;
            smallIntervalArray[1].yValue := 10.0;
            smallIntervalArray[2].yValue := 20.0;

            // Test interpolation at x=0.0015 (between 0.001 and 0.002)
            result := LGenComp_GetCompensationValueLinear(
                xValue := 0.0015,
                compensationArray := smallIntervalArray,
                status => status
            );

            // Should be 10.0 + (20.0-10.0) * (0.0015-0.001)/(0.002-0.001) = 10.0 + 5.0 = 15.0
            Equal(actual := result, expected := 15.0);
            Equal(actual := status, expected := LGenComp_GetCompensationValueStatus#STATE_VALID);
        END_METHOD
        {Test}
        METHOD PUBLIC TestLargeArray50Elements
            VAR
                largeArray : ARRAY[0..49] OF LGenComp_typeCompensationElement;
                i : INT;
            END_VAR

            // Create a large array with 50 points
            // X: [0.0, 2.0, 4.0, ..., 98.0]
            // Y: [0.0, 1.0, 4.0, 9.0, ..., 2401.0] (y = x^2 / 4)
            FOR i := 0 TO 49 DO
                largeArray[i].xValue := TO_LREAL(i * 2);
                largeArray[i].yValue := TO_LREAL(i * i);
            END_FOR;

            // Test interpolation at x=25.0 (between x=24.0 and x=26.0)
            // At i=12: x=24.0, y=144.0
            // At i=13: x=26.0, y=169.0
            result := LGenComp_GetCompensationValueLinear(
                xValue := 25.0,
                compensationArray := largeArray,
                status => status
            );

            // Should be 144.0 + (169.0-144.0) * (25.0-24.0)/(26.0-24.0) = 144.0 + 12.5 = 156.5
            Equal(actual := result, expected := 156.5);
            Equal(actual := status, expected := LGenComp_GetCompensationValueStatus#STATE_VALID);
        END_METHOD

        {Test}
        METHOD PUBLIC TestLargeArrayInterpolationNearStart
            VAR
                largeArray : ARRAY[0..49] OF LGenComp_typeCompensationElement;
                i : INT;
            END_VAR

            // Create a large array with 50 points
            // X: [0.0, 1.0, 2.0, ..., 49.0]
            // Y: [0.0, 10.0, 20.0, ..., 490.0] (y = x * 10)
            FOR i := 0 TO 49 DO
                largeArray[i].xValue := TO_LREAL(i);
                largeArray[i].yValue := TO_LREAL(i * 10);
            END_FOR;

            // Test interpolation near the start at x=1.5
            result := LGenComp_GetCompensationValueLinear(
                xValue := 1.5,
                compensationArray := largeArray,
                status => status
            );

            // Should be 10.0 + (20.0-10.0) * 0.5 = 15.0
            Equal(actual := result, expected := 15.0);
            Equal(actual := status, expected := LGenComp_GetCompensationValueStatus#STATE_VALID);
        END_METHOD

        {Test}
        METHOD PUBLIC TestLargeArrayInterpolationNearEnd
            VAR
                largeArray : ARRAY[0..49] OF LGenComp_typeCompensationElement;
                i : INT;
            END_VAR

            // Create a large array with 50 points
            // X: [0.0, 1.0, 2.0, ..., 49.0]
            // Y: [0.0, 10.0, 20.0, ..., 490.0]
            FOR i := 0 TO 49 DO
                largeArray[i].xValue := TO_LREAL(i);
                largeArray[i].yValue := TO_LREAL(i * 10);
            END_FOR;

            // Test interpolation near the end at x=47.7
            result := LGenComp_GetCompensationValueLinear(
                xValue := 47.7,
                compensationArray := largeArray,
                status => status
            );

            // Between x=47.0 (y=470.0) and x=48.0 (y=480.0)
            // Should be 470.0 + (480.0-470.0) * 0.7 = 477.0
            Equal(actual := result, expected := 477.0);
            Equal(actual := status, expected := LGenComp_GetCompensationValueStatus#STATE_VALID);
        END_METHOD

        {Test}
        METHOD PUBLIC TestLargeArrayClampingBelowMin
            VAR
                largeArray : ARRAY[0..49] OF LGenComp_typeCompensationElement;
                i : INT;
            END_VAR

            // Create a large array with 50 points starting at x=100.0
            // X: [100.0, 101.0, 102.0, ..., 149.0]
            // Y: [0.0, 5.0, 10.0, ..., 245.0]
            FOR i := 0 TO 49 DO
                largeArray[i].xValue := TO_LREAL(100 + i);
                largeArray[i].yValue := TO_LREAL(i * 5);
            END_FOR;

            // Test clamping below minimum
            result := LGenComp_GetCompensationValueLinear(
                xValue := 50.0,
                compensationArray := largeArray,
                status => status
            );

            // Should clamp to minimum and return value at x=100.0
            Equal(actual := result, expected := 0.0);
            Equal(actual := status, expected := LGenComp_GetCompensationValueStatus#WAR_RANGE_CLAMPING_ACTIVE);
        END_METHOD

        {Test}
        METHOD PUBLIC TestLargeArrayClampingAboveMax
            VAR
                largeArray : ARRAY[0..49] OF LGenComp_typeCompensationElement;
                i : INT;
            END_VAR

            // Create a large array with 50 points
            // X: [0.0, 1.0, 2.0, ..., 49.0]
            // Y: [1000.0, 1002.0, 1004.0, ..., 1098.0]
            FOR i := 0 TO 49 DO
                largeArray[i].xValue := TO_LREAL(i);
                largeArray[i].yValue := TO_LREAL(1000 + i * 2);
            END_FOR;

            // Test clamping above maximum
            result := LGenComp_GetCompensationValueLinear(
                xValue := 100.0,
                compensationArray := largeArray,
                status => status
            );

            // Should clamp to maximum and return value at x=49.0
            Equal(actual := result, expected := 1098.0);
            Equal(actual := status, expected := LGenComp_GetCompensationValueStatus#WAR_RANGE_CLAMPING_ACTIVE);
        END_METHOD

        {Test}
        METHOD PUBLIC TestLargeArrayNonUniformSpacing
            VAR
                largeArray : ARRAY[0..49] OF LGenComp_typeCompensationElement;
                i : INT;
            END_VAR

            // Create a large array with non-uniform spacing
            // First half: tight spacing, second half: wide spacing
            FOR i := 0 TO 24 DO
                largeArray[i].xValue := TO_LREAL(i * 2); // 0, 2, 4, ..., 48
                largeArray[i].yValue := TO_LREAL(i * 10);
            END_FOR;
            FOR i := 25 TO 49 DO
                largeArray[i].xValue := TO_LREAL(50 + (i - 25) * 20); // 50, 70, 90, ..., 530
                largeArray[i].yValue := TO_LREAL(250 + (i - 25) * 50);
            END_FOR;

            // Test interpolation in the wide-spacing section at x=150.0
            // Between x=130.0 (i=29: 50+4*20=130, y=250+4*50=450)
            // and x=150.0 (i=30: 50+5*20=150, y=250+5*50=500)
            result := LGenComp_GetCompensationValueLinear(
                xValue := 150.0,
                compensationArray := largeArray,
                status => status
            );

            // At exact point x=150.0, y=500.0
            Equal(actual := result, expected := 500.0);
            Equal(actual := status, expected := LGenComp_GetCompensationValueStatus#STATE_VALID);
        END_METHOD

        {Test}
        METHOD PUBLIC TestLargeArrayMiddleInterpolation
            VAR
                largeArray : ARRAY[0..49] OF LGenComp_typeCompensationElement;
                i : INT;
            END_VAR

            // Create a large linear array
            // X: [0.0, 5.0, 10.0, ..., 245.0]
            // Y: [0.0, 2.5, 5.0, ..., 122.5]
            FOR i := 0 TO 49 DO
                largeArray[i].xValue := TO_LREAL(i * 5);
                largeArray[i].yValue := TO_LREAL(i) * 2.5;
            END_FOR;

            // Test interpolation in the middle at x=122.5
            // Between x=120.0 (i=24, y=60.0) and x=125.0 (i=25, y=62.5)
            result := LGenComp_GetCompensationValueLinear(
                xValue := 122.5,
                compensationArray := largeArray,
                status => status
            );

            // Should be 60.0 + (62.5-60.0) * (122.5-120.0)/(125.0-120.0) = 60.0 + 1.25 = 61.25
            Equal(actual := result, expected := 61.25);
            Equal(actual := status, expected := LGenComp_GetCompensationValueStatus#STATE_VALID);
        END_METHOD

        {Test}
        METHOD PUBLIC TestLargeArrayInverseOrder
            VAR
                largeArray : ARRAY[0..49] OF LGenComp_typeCompensationElement;
                i : INT;
            END_VAR

            // Create a large array with descending x-values
            // X: [500.0, 490.0, 480.0, ..., 10.0]
            // Y: [0.0, 50.0, 100.0, ..., 2450.0]
            FOR i := 0 TO 49 DO
                largeArray[i].xValue := TO_LREAL(500 - i * 10);
                largeArray[i].yValue := TO_LREAL(i * 50);
            END_FOR;

            // Test interpolation at x=255.0
            // Between x=260.0 (i=24, y=1200.0) and x=250.0 (i=25, y=1250.0)
            result := LGenComp_GetCompensationValueLinear(
                xValue := 255.0,
                compensationArray := largeArray,
                status => status
            );

            // Should be 1200.0 + (1250.0-1200.0) * (255.0-260.0)/(250.0-260.0)
            // = 1200.0 + 50.0 * 0.5 = 1225.0
            Equal(actual := result, expected := 1225.0);
            Equal(actual := status, expected := LGenComp_GetCompensationValueStatus#STATE_VALID);
        END_METHOD
            {Test}
        METHOD PUBLIC TestSingleElementArray
            VAR
                singleElementArray : ARRAY[0..0] OF LGenComp_typeCompensationElement;
            END_VAR

            // Create a single element array
            singleElementArray[0].xValue := 42.0;
            singleElementArray[0].yValue := 100.0;

            // Test with x-value equal to the single element
            result := LGenComp_GetCompensationValueLinear(
                xValue := 42.0,
                compensationArray := singleElementArray,
                status => status
            );

            // Should return the single y-value
            Equal(actual := result, expected := 100.0);
            Equal(actual := status, expected := LGenComp_GetCompensationValueStatus#STATE_VALID);
        END_METHOD

        {Test}
        METHOD PUBLIC TestSingleElementArrayDifferentXValue
            VAR
                singleElementArray : ARRAY[0..0] OF LGenComp_typeCompensationElement;
            END_VAR

            // Create a single element array
            singleElementArray[0].xValue := 10.0;
            singleElementArray[0].yValue := 50.0;

            // Test with x-value different from the single element
            result := LGenComp_GetCompensationValueLinear(
                xValue := 100.0,
                compensationArray := singleElementArray,
                status => status
            );

            // Should return the single y-value but with clamping warning
            Equal(actual := result, expected := 50.0);
            Equal(actual := status, expected := LGenComp_GetCompensationValueStatus#WAR_RANGE_CLAMPING_ACTIVE);
        END_METHOD
        {Test}
        METHOD PUBLIC TestNegativeIndexArray
            VAR
                negativeIndexArray : ARRAY[-10..-6] OF LGenComp_typeCompensationElement;
            END_VAR

            // Create array with negative indices [-10..-6]
            // X: [0.0, 10.0, 20.0, 30.0, 40.0]
            // Y: [0.0, 5.0, 15.0, 20.0, 30.0]
            negativeIndexArray[-10].xValue := 0.0;
            negativeIndexArray[-9].xValue := 10.0;
            negativeIndexArray[-8].xValue := 20.0;
            negativeIndexArray[-7].xValue := 30.0;
            negativeIndexArray[-6].xValue := 40.0;

            negativeIndexArray[-10].yValue := 0.0;
            negativeIndexArray[-9].yValue := 5.0;
            negativeIndexArray[-8].yValue := 15.0;
            negativeIndexArray[-7].yValue := 20.0;
            negativeIndexArray[-6].yValue := 30.0;

            // Test interpolation at x=25.0 (between x=20.0 and x=30.0)
            result := LGenComp_GetCompensationValueLinear(
                xValue := 25.0,
                compensationArray := negativeIndexArray,
                status => status
            );

            // Should be 15.0 + (20.0-15.0) * (25.0-20.0)/(30.0-20.0) = 17.5
            Equal(actual := result, expected := 17.5);
            Equal(actual := status, expected := LGenComp_GetCompensationValueStatus#STATE_VALID);
        END_METHOD

        {Test}
        METHOD PUBLIC TestNegativeToPositiveIndexArray
            VAR
                crossZeroArray : ARRAY[-3..3] OF LGenComp_typeCompensationElement;
            END_VAR

            // Create array spanning negative to positive indices [-3..3]
            // X: [-30.0, -20.0, -10.0, 0.0, 10.0, 20.0, 30.0]
            // Y: [9.0, 4.0, 1.0, 0.0, 1.0, 4.0, 9.0] (parabola y = x²/100)
            crossZeroArray[-3].xValue := -30.0;
            crossZeroArray[-2].xValue := -20.0;
            crossZeroArray[-1].xValue := -10.0;
            crossZeroArray[0].xValue := 0.0;
            crossZeroArray[1].xValue := 10.0;
            crossZeroArray[2].xValue := 20.0;
            crossZeroArray[3].xValue := 30.0;

            crossZeroArray[-3].yValue := 9.0;
            crossZeroArray[-2].yValue := 4.0;
            crossZeroArray[-1].yValue := 1.0;
            crossZeroArray[0].yValue := 0.0;
            crossZeroArray[1].yValue := 1.0;
            crossZeroArray[2].yValue := 4.0;
            crossZeroArray[3].yValue := 9.0;

            // Test interpolation at x=15.0 (between x=10.0 and x=20.0)
            result := LGenComp_GetCompensationValueLinear(
                xValue := 15.0,
                compensationArray := crossZeroArray,
                status => status
            );

            // Should be 1.0 + (4.0-1.0) * (15.0-10.0)/(20.0-10.0) = 1.0 + 1.5 = 2.5
            Equal(actual := result, expected := 2.5);
            Equal(actual := status, expected := LGenComp_GetCompensationValueStatus#STATE_VALID);
        END_METHOD

        {Test}
        METHOD PUBLIC TestPositiveOffsetIndexArray
            VAR
                offsetArray : ARRAY[100..105] OF LGenComp_typeCompensationElement;
            END_VAR

            // Create array with high positive offset [100..105]
            // X: [0.0, 20.0, 40.0, 60.0, 80.0, 100.0]
            // Y: [100.0, 120.0, 140.0, 160.0, 180.0, 200.0]
            offsetArray[100].xValue := 0.0;
            offsetArray[101].xValue := 20.0;
            offsetArray[102].xValue := 40.0;
            offsetArray[103].xValue := 60.0;
            offsetArray[104].xValue := 80.0;
            offsetArray[105].xValue := 100.0;

            offsetArray[100].yValue := 100.0;
            offsetArray[101].yValue := 120.0;
            offsetArray[102].yValue := 140.0;
            offsetArray[103].yValue := 160.0;
            offsetArray[104].yValue := 180.0;
            offsetArray[105].yValue := 200.0;

            // Test interpolation at x=50.0 (between x=40.0 and x=60.0)
            result := LGenComp_GetCompensationValueLinear(
                xValue := 50.0,
                compensationArray := offsetArray,
                status => status
            );

            // Should be 140.0 + (160.0-140.0) * (50.0-40.0)/(60.0-40.0) = 140.0 + 10.0 = 150.0
            Equal(actual := result, expected := 150.0);
            Equal(actual := status, expected := LGenComp_GetCompensationValueStatus#STATE_VALID);
        END_METHOD

        {Test}
        METHOD PUBLIC TestNegativeIndexClampingBehavior
            VAR
                negativeArray : ARRAY[-5..-1] OF LGenComp_typeCompensationElement;
            END_VAR

            // Create array with negative indices [-5..-1]
            // X: [10.0, 20.0, 30.0, 40.0, 50.0]
            // Y: [100.0, 200.0, 300.0, 400.0, 500.0]
            negativeArray[-5].xValue := 10.0;
            negativeArray[-4].xValue := 20.0;
            negativeArray[-3].xValue := 30.0;
            negativeArray[-2].xValue := 40.0;
            negativeArray[-1].xValue := 50.0;

            negativeArray[-5].yValue := 100.0;
            negativeArray[-4].yValue := 200.0;
            negativeArray[-3].yValue := 300.0;
            negativeArray[-2].yValue := 400.0;
            negativeArray[-1].yValue := 500.0;

            // Test clamping below minimum
            result := LGenComp_GetCompensationValueLinear(
                xValue := 5.0,
                compensationArray := negativeArray,
                status => status
            );

            // Should clamp to minimum and return value at x=10.0
            Equal(actual := result, expected := 100.0);
            Equal(actual := status, expected := LGenComp_GetCompensationValueStatus#WAR_RANGE_CLAMPING_ACTIVE);
        END_METHOD

        {Test}
        METHOD PUBLIC TestNegativeIndexInverseOrder
            VAR
                inverseNegArray : ARRAY[-8..-4] OF LGenComp_typeCompensationElement;
            END_VAR

            // Create inverse array with negative indices [-8..-4]
            // X: [40.0, 30.0, 20.0, 10.0, 0.0] (descending)
            // Y: [30.0, 20.0, 15.0, 5.0, 0.0]
            inverseNegArray[-8].xValue := 40.0;
            inverseNegArray[-7].xValue := 30.0;
            inverseNegArray[-6].xValue := 20.0;
            inverseNegArray[-5].xValue := 10.0;
            inverseNegArray[-4].xValue := 0.0;

            inverseNegArray[-8].yValue := 30.0;
            inverseNegArray[-7].yValue := 20.0;
            inverseNegArray[-6].yValue := 15.0;
            inverseNegArray[-5].yValue := 5.0;
            inverseNegArray[-4].yValue := 0.0;

            // Test interpolation at x=25.0
            result := LGenComp_GetCompensationValueLinear(
                xValue := 25.0,
                compensationArray := inverseNegArray,
                status => status
            );

            // Should be 20.0 + (15.0-20.0) * (25.0-30.0)/(20.0-30.0) = 20.0 - 2.5 = 17.5
            Equal(actual := result, expected := 17.5);
            Equal(actual := status, expected := LGenComp_GetCompensationValueStatus#STATE_VALID);
        END_METHOD

        {Test}
        METHOD PUBLIC TestSingleElementNegativeIndex
            VAR
                singleNegArray : ARRAY[-42..-42] OF LGenComp_typeCompensationElement;
            END_VAR

            // Create single element array with negative index
            singleNegArray[-42].xValue := 99.0;
            singleNegArray[-42].yValue := 123.45;

            // Test with matching x-value
            result := LGenComp_GetCompensationValueLinear(
                xValue := 99.0,
                compensationArray := singleNegArray,
                status => status
            );

            Equal(actual := result, expected := 123.45);
            Equal(actual := status, expected := LGenComp_GetCompensationValueStatus#STATE_VALID);
        END_METHOD

        {Test}
        METHOD PUBLIC TestLargeNegativeIndexArray
            VAR
                largeNegArray : ARRAY[-30..19] OF LGenComp_typeCompensationElement;
                i : INT;
            END_VAR

            // Create a large array with 50 elements spanning negative to positive indices [-30..19]
            // X: [0.0, 2.0, 4.0, ..., 98.0]
            // Y: [0.0, 10.0, 20.0, ..., 490.0]
            FOR i := -30 TO 19 DO
                largeNegArray[i].xValue := TO_LREAL((i + 30) * 2);
                largeNegArray[i].yValue := TO_LREAL((i + 30) * 10);
            END_FOR;

            // Test interpolation at x=51.0
            // At i=-5 (actual index 25): x=50.0, y=250.0
            // At i=-4 (actual index 26): x=52.0, y=260.0
            result := LGenComp_GetCompensationValueLinear(
                xValue := 51.0,
                compensationArray := largeNegArray,
                status => status
            );

            // Should be 250.0 + (260.0-250.0) * (51.0-50.0)/(52.0-50.0) = 250.0 + 5.0 = 255.0
            Equal(actual := result, expected := 255.0);
            Equal(actual := status, expected := LGenComp_GetCompensationValueStatus#STATE_VALID);
        END_METHOD
    END_CLASS
END_NAMESPACE