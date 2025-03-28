//
//  ThermalForecastFunc.swift
//  CloudbaseUtah
//
//  Created by Brown, Mike on 3/27/25.
//
import SwiftUI

struct ThermalCalculationResult {
    let thermalVelocity: Double?
    let cloudbaseAltitude: Double?
    let topOfLiftAltitude: Double?
}

func calculateThermalVelocity(
    altitude: Double,
    ambientTemp: Double,
    ambientDPTemp: Double,
    priorAmbientDPTemp: Double,
    priorThermalDPTemp: Double,
    priorAltitude: Double,
    surfaceAltitude: Double
) -> ThermalCalculationResult? {
    
    // Check if altitude is less than surfaceAltitude
    guard altitude >= surfaceAltitude else {
        return nil // End processing if altitude is less than surfaceAltitude
    }
    
    // Check if priorAltitude is less than surfaceAltitude
    let adjustedPriorAltitude = priorAltitude < surfaceAltitude ? surfaceAltitude : priorAltitude
    
    // Constants
    let DALR = 9.8 // Dry Adiabatic Lapse Rate in °C/km
    let feetToKm = 0.0003048 // Conversion factor from feet to kilometers
    let thermalRampDistance = 500.0 // Thermal ramp distance in feet
    let thermalReductionFactor = 0.5 // Thermal reduction factor
    
    // Calculate the thermal ramp top
    let thermalRampTop = surfaceAltitude + thermalRampDistance
    
    // Determine if cloudbase is reached and calculate cloudbaseAltitude
    var cloudbaseAltitude: Double? = nil
    if ambientTemp <= ambientDPTemp {
        let tempRatio = (ambientTemp - priorAmbientDPTemp) / (ambientDPTemp - priorAmbientDPTemp)
        cloudbaseAltitude = adjustedPriorAltitude + tempRatio * (altitude - adjustedPriorAltitude)
    }
    
    // Determine if top of lift is reached and calculate topOfLiftAltitude
    var topOfLiftAltitude: Double? = nil
    if priorThermalDPTemp <= ambientDPTemp {
        let liftRatio = (priorAmbientDPTemp - priorThermalDPTemp) / (priorAmbientDPTemp - ambientDPTemp)
        if liftRatio > 0 {
            topOfLiftAltitude = adjustedPriorAltitude + liftRatio * (altitude - adjustedPriorAltitude)
        } else {
            topOfLiftAltitude = adjustedPriorAltitude
        }
    }
    
    // Calculate the thermal velocity using DALR only if cloudbase or top of lift is not reached
    var thermalVelocity: Double? = nil
    if cloudbaseAltitude == nil && topOfLiftAltitude == nil {
        
        // Convert altitude from feet to kilometers
        let altitudeKm = altitude * feetToKm
        let adjustedPriorAltitudeKm = adjustedPriorAltitude * feetToKm
        
        // Calculate temperature difference
        let tempDifference = ambientTemp - ambientDPTemp
        
        // Calculate the thermal velocity using DALR
        thermalVelocity = (tempDifference / DALR) * (altitudeKm - adjustedPriorAltitudeKm)
        
        // Adjust thermal velocity if within thermal ramp distance (near the surface)
        if thermalRampTop > adjustedPriorAltitude {
            let rampImpactAltitude = min(altitude, thermalRampTop) - adjustedPriorAltitude
            let rampImpactPortion = rampImpactAltitude / (altitude - adjustedPriorAltitude)
            let proratedReduction = thermalReductionFactor * rampImpactPortion
            thermalVelocity = thermalVelocity! * (1 - proratedReduction)
        }
    }
    
    return ThermalCalculationResult(
        thermalVelocity: thermalVelocity,
        cloudbaseAltitude: cloudbaseAltitude,
        topOfLiftAltitude: topOfLiftAltitude
    )
}
