USING System.Math;
NAMESPACE Simatic.Ax.LGenComp
    ///===============================================================================
    /// SIEMENS AG / (c)Copyright 2025
    ///-------------------------------------------------------------------------------
    /// Title:            LGenComp_GetCompensationValueLinear
    /// Comment/Function: Function for retrieving a compensation value from a
    ///                   compensation array for a given x-value.
    /// Library/Family:   LGenComp
    /// Author:           APC Erlangen
    /// Engineering:      SIMATIC AX
    ///===============================================================================
    FUNCTION LGenComp_GetCompensationValueLinear : LREAL
        VAR_INPUT
            xValue : LREAL;   // input for array lookup
            compensationArray : ARRAY[*] of LGenComp_typeCompensationElement;
        END_VAR

        VAR_OUTPUT
            status : LGenComp_GetCompensationValueStatus;   // Status information
        END_VAR

        VAR_TEMP
            tempLowerBoundary : DINT;  // Lower array index boundary
            tempUpperBoundary : DINT;  // Upper array index boundary
            tempXMin : LREAL;          // Minimum x-value in the compensation table
            tempXMax : LREAL;          // Maximum x-value in the compensation table

            tempXValue : LREAL;        // Clamped input value within valid range
            tempIndexStart : DINT;     // Start index for binary search
            tempIndexEnd : DINT;       // End index for binary search
            tempIndex : DINT;          // Current middle index during binary search
            tempInverse : BOOL;        // TRUE if array is sorted in descending order
            tempXValue1 : LREAL;       // X-value of first interpolation point
            tempXValue2 : LREAL;       // X-value of second interpolation point
            tempYValue1 : LREAL;       // Y-value of first interpolation point
            tempYValue2 : LREAL;       // Y-value of second interpolation point
        END_VAR


        // Initialize status to valid
        status := LGenComp_GetCompensationValueStatus#STATE_VALID;

        // Get array boundaries
        tempLowerBoundary := LOWER_BOUND(compensationArray,1);
        tempUpperBoundary := UPPER_BOUND(compensationArray,1);

        // Handle edge case: single element array
        // If array has only one element, return that element's y-value
        IF tempUpperBoundary = tempLowerBoundary THEN
            // Return the only available y-value
            LGenComp_GetCompensationValueLinear := compensationArray[tempLowerBoundary].yValue;
            // Check if input matches the single point's x-value
            IF xValue = compensationArray[tempLowerBoundary].xValue THEN
                status := LGenComp_GetCompensationValueStatus#STATE_VALID;
            ELSE
                // Input is outside range, clamping was applied
                status := LGenComp_GetCompensationValueStatus#WAR_RANGE_CLAMPING_ACTIVE;
            END_IF;
            RETURN;
        END_IF;

        // Initialize binary search indices
        tempIndexStart := tempLowerBoundary;
        tempIndexEnd := tempUpperBoundary;

        // Determine if array is sorted in descending order (inverse)
        tempInverse := compensationArray[tempIndexEnd].xValue < compensationArray[tempIndexStart].xValue;
        // Determine min and max x-values based on array sort order
        IF NOT tempInverse THEN
            // Array sorted in ascending order
            tempXMin := compensationArray[tempLowerBoundary].xValue;
            tempXMax := compensationArray[tempUpperBoundary].xValue;
        ELSE
            // Array sorted in descending order
            tempXMin := compensationArray[tempUpperBoundary].xValue;
            tempXMax := compensationArray[tempLowerBoundary].xValue;
        END_IF;

        // Clamp input value to valid range [tempXMin, tempXMax]
        tempXValue := Clamp(value := xValue, min := tempXMin, max := tempXMax);
        // Set warning status if clamping occurred
        IF xValue < tempXMin OR xValue > tempXMax THEN
            status := LGenComp_GetCompensationValueStatus#WAR_RANGE_CLAMPING_ACTIVE;
        END_IF;

        // Binary search to find the two adjacent points that bracket tempXValue
        // Continue until the search range is reduced to two adjacent elements
        WHILE (tempIndexEnd - tempIndexStart) >= UINT#2 DO
            // Calculate middle index
            tempIndex := (tempIndexEnd + tempIndexStart) / DINT#2;
            // Determine which half of the search space contains tempXValue
            IF (compensationArray[tempIndex].xValue >= tempXValue AND NOT tempInverse) OR
                (compensationArray[tempIndex].xValue <= tempXValue AND tempInverse) THEN
                // Target is in lower half (or equal to middle)
                tempIndexEnd := tempIndex;
            ELSE
                // Target is in upper half
                tempIndexStart := tempIndex;
            END_IF;
        END_WHILE;

        // Extract the two interpolation points from the table
        tempXValue1 := compensationArray[tempIndexStart].xValue;
        tempXValue2 := compensationArray[tempIndexEnd].xValue;
        tempYValue1 := compensationArray[tempIndexStart].yValue;
        tempYValue2 := compensationArray[tempIndexEnd].yValue;

        // Perform linear interpolation
        IF tempXValue1 = tempXValue2 THEN
            // Handle edge case: both points have same x-value
            // Return average of both y-values
            LGenComp_GetCompensationValueLinear := (tempYValue1 + tempYValue2) / 2.0;
        ELSE
            // Standard linear interpolation formula: y = y1 + (y2-y1) * (x-x1) / (x2-x1)
            LGenComp_GetCompensationValueLinear := tempYValue1 + (tempYValue2 - tempYValue1) * (tempXValue - tempXValue1) / (tempXValue2 - tempXValue1);
        END_IF;
    END_FUNCTION
END_NAMESPACE