# LGenComp_typeSensorAddressIn

## Description

Data structure representing the memory address configuration for accessing sensor data of a SIMATIC Motion Control Technology Object.

## Structure

| Field | Type | Description |
|--------|------|-------------|
| dbNumber | UINT | Data block number where the sensor data is stored |
| offset | DINT | Byte offset within the data block pointing to the sensor value location |
| area | BYTE | Memory area identifier (e.g., DB for data blocks, M for memory, I for inputs, Q for outputs) |

## Usage

This type is used for internal sensor data access from SIMATIC Motion Control Technology Objects.


