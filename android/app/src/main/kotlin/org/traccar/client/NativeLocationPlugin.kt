package org.traccar.client

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Native Android LocationManager fallback for Force Location
 * Based on the original Traccar client's simple approach
 */
class NativeLocationPlugin: FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var foregroundChannel: MethodChannel
    private lateinit var context: Context
    private lateinit var locationManager: LocationManager
    
    companion object {
        private const val TAG = "NativeLocationPlugin"
        private const val CHANNEL = "native_location"
        private const val FOREGROUND_CHANNEL = "foreground_service"
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
        
        foregroundChannel = MethodChannel(flutterPluginBinding.binaryMessenger, FOREGROUND_CHANNEL)
        foregroundChannel.setMethodCallHandler(this)
        
        context = flutterPluginBinding.applicationContext
        locationManager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            // Location methods
            "requestSingleLocation" -> {
                val timeout = call.argument<Int>("timeout") ?: 30000
                val accuracy = call.argument<Double>("accuracy") ?: 100.0
                requestSingleLocation(timeout, accuracy, result)
            }
            "getLastKnownLocation" -> {
                getLastKnownLocation(result)
            }
            "isLocationEnabled" -> {
                result.success(isLocationEnabled())
            }
            "hasLocationPermission" -> {
                result.success(hasLocationPermission())
            }
            // Foreground service methods
            "start" -> {
                LocationForegroundService.startService(context)
                result.success(true)
            }
            "stop" -> {
                LocationForegroundService.stopService(context)
                result.success(true)
            }
            "isRunning" -> {
                // Simple check - in a real implementation you'd check if service is actually running
                result.success(true)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        foregroundChannel.setMethodCallHandler(null)
    }
    
    private fun hasLocationPermission(): Boolean {
        return ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
               ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
    }
    
    private fun isLocationEnabled(): Boolean {
        return try {
            locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
            locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
        } catch (e: Exception) {
            Log.w(TAG, "Error checking location enabled", e)
            false
        }
    }
    
    @Suppress("MissingPermission")
    private fun getLastKnownLocation(result: Result) {
        if (!hasLocationPermission()) {
            result.error("PERMISSION_DENIED", "Location permission not granted", null)
            return
        }
        
        try {
            // Try GPS first, then Network, then Passive (like original Traccar client)
            val providers = listOf(
                LocationManager.GPS_PROVIDER,
                LocationManager.NETWORK_PROVIDER,
                LocationManager.PASSIVE_PROVIDER
            )
            
            var bestLocation: Location? = null
            var bestTime = 0L
            
            for (provider in providers) {
                if (locationManager.isProviderEnabled(provider)) {
                    val location = locationManager.getLastKnownLocation(provider)
                    if (location != null && location.time > bestTime) {
                        bestLocation = location
                        bestTime = location.time
                    }
                }
            }
            
            if (bestLocation != null) {
                result.success(locationToMap(bestLocation))
            } else {
                result.success(null)
            }
        } catch (e: Exception) {
            Log.w(TAG, "Error getting last known location", e)
            result.error("LOCATION_ERROR", e.message, null)
        }
    }
    
    @Suppress("MissingPermission")
    private fun requestSingleLocation(timeoutMs: Int, accuracyMeters: Double, result: Result) {
        if (!hasLocationPermission()) {
            result.error("PERMISSION_DENIED", "Location permission not granted", null)
            return
        }
        
        if (!isLocationEnabled()) {
            result.error("LOCATION_DISABLED", "Location services are disabled", null)
            return
        }
        
        // First try to get last known location (instant)
        getLastKnownLocation(object : Result {
            override fun success(location: Any?) {
                if (location != null) {
                    Log.i(TAG, "Using last known location for single request")
                    result.success(location)
                } else {
                    // No cached location, request fresh one
                    requestFreshLocation(timeoutMs, accuracyMeters, result)
                }
            }
            
            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                // Failed to get cached location, try fresh request
                requestFreshLocation(timeoutMs, accuracyMeters, result)
            }
            
            override fun notImplemented() {
                requestFreshLocation(timeoutMs, accuracyMeters, result)
            }
        })
    }
    
    @Suppress("MissingPermission")
    private fun requestFreshLocation(timeoutMs: Int, accuracyMeters: Double, result: Result) {
        Log.i(TAG, "Requesting fresh location with timeout ${timeoutMs}ms")
        
        // Choose best available provider
        val provider = when {
            locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER) -> LocationManager.GPS_PROVIDER
            locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER) -> LocationManager.NETWORK_PROVIDER
            else -> {
                result.error("NO_PROVIDER", "No location provider available", null)
                return
            }
        }
        
        val handler = Handler(Looper.getMainLooper())
        var locationReceived = false
        
        val locationListener = object : LocationListener {
            override fun onLocationChanged(location: Location) {
                if (!locationReceived && location.accuracy <= accuracyMeters) {
                    locationReceived = true
                    locationManager.removeUpdates(this)
                    Log.i(TAG, "Received location from $provider with accuracy ${location.accuracy}m")
                    result.success(locationToMap(location))
                }
            }
            
            override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
            override fun onProviderEnabled(provider: String) {}
            override fun onProviderDisabled(provider: String) {}
        }
        
        // Set timeout
        val timeoutRunnable = Runnable {
            if (!locationReceived) {
                locationReceived = true
                locationManager.removeUpdates(locationListener)
                Log.w(TAG, "Location request timed out after ${timeoutMs}ms")
                result.error("TIMEOUT", "Location request timed out", null)
            }
        }
        
        try {
            // Request location updates
            locationManager.requestLocationUpdates(
                provider,
                1000L, // 1 second minimum interval
                0f,    // No minimum distance
                locationListener,
                Looper.getMainLooper()
            )
            
            // Set timeout
            handler.postDelayed(timeoutRunnable, timeoutMs.toLong())
            
        } catch (e: Exception) {
            Log.w(TAG, "Error requesting location updates", e)
            result.error("LOCATION_ERROR", e.message, null)
        }
    }
    
    private fun locationToMap(location: Location): Map<String, Any> {
        return mapOf(
            "latitude" to location.latitude,
            "longitude" to location.longitude,
            "accuracy" to location.accuracy.toDouble(),
            "altitude" to location.altitude,
            "speed" to location.speed.toDouble(),
            "bearing" to location.bearing.toDouble(),
            "timestamp" to location.time,
            "provider" to (location.provider ?: "unknown")
        )
    }
}