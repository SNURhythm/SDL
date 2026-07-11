/*
  Simple DirectMedia Layer
  Copyright (C) 1997-2026 Sam Lantinga <slouken@libsdl.org>

  This software is provided 'as-is', without any express or implied
  warranty.  In no event will the authors be held liable for any damages
  arising from the use of this software.

  Permission is granted to anyone to use this software for any purpose,
  including commercial applications, and to alter it and redistribute it
  freely, subject to the following restrictions:

  1. The origin of this software must not be misrepresented; you must not
     claim that you wrote the original software. If you use this software
     in a product, an acknowledgment in the product documentation would be
     appreciated but is not required.
  2. Altered source versions must be plainly marked as such, and must not be
     misrepresented as being the original software.
  3. This notice may not be removed or altered from any source distribution.
*/

#include "SDL_config.h"

#ifdef SDL_SENSOR_COREMOTION

/* This is the system specific header for the SDL sensor API */
#include <CoreMotion/CoreMotion.h>

#include "SDL_error.h"
#include "SDL_sensor.h"
#include "SDL_coremotionsensor.h"
#include "../SDL_syssensor.h"
#include "../SDL_sensor_c.h"

#include <TargetConditionals.h>

typedef struct
{
    enum
    {
        SDL_COREMOTION_ACCELEROMETER = SDL_SENSOR_ACCEL,
        SDL_COREMOTION_GYROSCOPE = SDL_SENSOR_GYRO,
        SDL_COREMOTION_CORRECTED_DEVICE_MOTION = 0x10000
    } kind;
    SDL_SensorType type;
    SDL_SensorID instance_id;
} SDL_CoreMotionSensor;

static CMMotionManager *SDL_motion_manager;
static SDL_CoreMotionSensor *SDL_sensors;
static int SDL_sensors_count;

CMMotionManager *SDL_COREMOTION_GetMotionManager(void)
{
    if (!SDL_motion_manager) {
        SDL_motion_manager = [[CMMotionManager alloc] init];
    }
    return SDL_motion_manager;
}

#if TARGET_OS_IOS
static CMAttitudeReferenceFrame SDL_device_motion_reference_frame;

static CMAttitudeReferenceFrame SDL_COREMOTION_GetCorrectedReferenceFrame(void)
{
    const CMAttitudeReferenceFrame frames = [CMMotionManager availableAttitudeReferenceFrames];
    if ((frames & CMAttitudeReferenceFrameXArbitraryCorrectedZVertical) != 0) {
        return CMAttitudeReferenceFrameXArbitraryCorrectedZVertical;
    }
    if ((frames & CMAttitudeReferenceFrameXMagneticNorthZVertical) != 0) {
        return CMAttitudeReferenceFrameXMagneticNorthZVertical;
    }
    return (CMAttitudeReferenceFrame)0;
}
#endif

static int SDL_COREMOTION_SensorInit(void)
{
    int i, sensors_count = 0;

    SDL_motion_manager = SDL_COREMOTION_GetMotionManager();

    if (SDL_motion_manager.accelerometerAvailable) {
        ++sensors_count;
    }
    if (SDL_motion_manager.gyroAvailable) {
        ++sensors_count;
    }
#if TARGET_OS_IOS
    SDL_device_motion_reference_frame = SDL_COREMOTION_GetCorrectedReferenceFrame();
    if (SDL_motion_manager.deviceMotionAvailable && SDL_motion_manager.magnetometerAvailable && SDL_device_motion_reference_frame != 0) {
        ++sensors_count;
    }
#endif

    if (sensors_count > 0) {
        SDL_sensors = (SDL_CoreMotionSensor *)SDL_calloc(sensors_count, sizeof(*SDL_sensors));
        if (!SDL_sensors) {
            return SDL_OutOfMemory();
        }

        i = 0;
        if (SDL_motion_manager.accelerometerAvailable) {
            SDL_sensors[i].kind = SDL_COREMOTION_ACCELEROMETER;
            SDL_sensors[i].type = SDL_SENSOR_ACCEL;
            SDL_sensors[i].instance_id = SDL_GetNextSensorInstanceID();
            ++i;
        }
        if (SDL_motion_manager.gyroAvailable) {
            SDL_sensors[i].kind = SDL_COREMOTION_GYROSCOPE;
            SDL_sensors[i].type = SDL_SENSOR_GYRO;
            SDL_sensors[i].instance_id = SDL_GetNextSensorInstanceID();
            ++i;
        }
#if TARGET_OS_IOS
        if (SDL_motion_manager.deviceMotionAvailable && SDL_motion_manager.magnetometerAvailable && SDL_device_motion_reference_frame != 0) {
            SDL_sensors[i].kind = SDL_COREMOTION_CORRECTED_DEVICE_MOTION;
            SDL_sensors[i].type = SDL_SENSOR_UNKNOWN;
            SDL_sensors[i].instance_id = SDL_GetNextSensorInstanceID();
            ++i;
        }
#endif
        SDL_sensors_count = sensors_count;
    }
    return 0;
}

static int SDL_COREMOTION_SensorGetCount(void)
{
    return SDL_sensors_count;
}

static void SDL_COREMOTION_SensorDetect(void)
{
}

static const char *SDL_COREMOTION_SensorGetDeviceName(int device_index)
{
    switch (SDL_sensors[device_index].kind) {
    case SDL_COREMOTION_ACCELEROMETER:
        return "Accelerometer";
    case SDL_COREMOTION_GYROSCOPE:
        return "Gyro";
    case SDL_COREMOTION_CORRECTED_DEVICE_MOTION:
        return "Corrected Device Motion";
    default:
        return "Unknown";
    }
}

static SDL_SensorType SDL_COREMOTION_SensorGetDeviceType(int device_index)
{
    return SDL_sensors[device_index].type;
}

static int SDL_COREMOTION_SensorGetDeviceNonPortableType(int device_index)
{
    return SDL_sensors[device_index].kind;
}

static SDL_SensorID SDL_COREMOTION_SensorGetDeviceInstanceID(int device_index)
{
    return SDL_sensors[device_index].instance_id;
}

static int SDL_COREMOTION_SensorOpen(SDL_Sensor *sensor, int device_index)
{
    struct sensor_hwdata *hwdata;

    hwdata = (struct sensor_hwdata *)SDL_calloc(1, sizeof(*hwdata));
    if (hwdata == NULL) {
        return SDL_OutOfMemory();
    }
    sensor->hwdata = hwdata;

    switch (SDL_sensors[device_index].kind) {
    case SDL_COREMOTION_ACCELEROMETER:
        SDL_motion_manager.accelerometerUpdateInterval = 1.0 / 120.0;
        [SDL_motion_manager startAccelerometerUpdates];
        break;
    case SDL_COREMOTION_GYROSCOPE:
        SDL_motion_manager.gyroUpdateInterval = 1.0 / 120.0;
        [SDL_motion_manager startGyroUpdates];
        break;
#if TARGET_OS_IOS
    case SDL_COREMOTION_CORRECTED_DEVICE_MOTION:
        SDL_motion_manager.deviceMotionUpdateInterval = 1.0 / 120.0;
        SDL_motion_manager.showsDeviceMovementDisplay = YES;
        [SDL_motion_manager startDeviceMotionUpdatesUsingReferenceFrame:SDL_device_motion_reference_frame];
        break;
#endif
    default:
        break;
    }
    return 0;
}

static Uint64 SDL_COREMOTION_GetTimestamp(CMLogItem *item)
{
    const NSTimeInterval timestamp = item.timestamp;
    return timestamp > 0.0 ? (Uint64)(timestamp * 1000000.0) : 0;
}

static void SDL_COREMOTION_SensorUpdate(SDL_Sensor *sensor)
{
    switch (sensor->non_portable_type) {
    case SDL_COREMOTION_ACCELEROMETER:
    {
        CMAccelerometerData *accelerometerData = SDL_motion_manager.accelerometerData;
        if (accelerometerData) {
            CMAcceleration acceleration = accelerometerData.acceleration;
            Uint64 timestamp_us = SDL_COREMOTION_GetTimestamp(accelerometerData);
            float data[3];
            data[0] = -acceleration.x * SDL_STANDARD_GRAVITY;
            data[1] = -acceleration.y * SDL_STANDARD_GRAVITY;
            data[2] = -acceleration.z * SDL_STANDARD_GRAVITY;
            if (timestamp_us != sensor->hwdata->timestamp_us || SDL_memcmp(data, sensor->hwdata->data, sizeof(data)) != 0) {
                SDL_PrivateSensorUpdate(sensor, timestamp_us, data, SDL_arraysize(data));
                sensor->hwdata->timestamp_us = timestamp_us;
                SDL_memcpy(sensor->hwdata->data, data, sizeof(data));
            }
        }
    } break;
    case SDL_COREMOTION_GYROSCOPE:
    {
        CMGyroData *gyroData = SDL_motion_manager.gyroData;
        if (gyroData) {
            CMRotationRate rotationRate = gyroData.rotationRate;
            Uint64 timestamp_us = SDL_COREMOTION_GetTimestamp(gyroData);
            float data[3];
            data[0] = rotationRate.x;
            data[1] = rotationRate.y;
            data[2] = rotationRate.z;
            if (timestamp_us != sensor->hwdata->timestamp_us || SDL_memcmp(data, sensor->hwdata->data, sizeof(data)) != 0) {
                SDL_PrivateSensorUpdate(sensor, timestamp_us, data, SDL_arraysize(data));
                sensor->hwdata->timestamp_us = timestamp_us;
                SDL_memcpy(sensor->hwdata->data, data, sizeof(data));
            }
        }
    } break;
#if TARGET_OS_IOS
    case SDL_COREMOTION_CORRECTED_DEVICE_MOTION:
    {
        CMDeviceMotion *deviceMotion = SDL_motion_manager.deviceMotion;
        if (deviceMotion) {
            CMRotationRate rotationRate = deviceMotion.rotationRate;
            CMAcceleration gravity = deviceMotion.gravity;
            Uint64 timestamp_us = SDL_COREMOTION_GetTimestamp(deviceMotion);
            float data[8];
            data[0] = deviceMotion.attitude.yaw;
            data[1] = rotationRate.x;
            data[2] = rotationRate.y;
            data[3] = rotationRate.z;
            data[4] = gravity.x;
            data[5] = gravity.y;
            data[6] = gravity.z;
            data[7] = deviceMotion.magneticField.accuracy;
            if (timestamp_us != sensor->hwdata->timestamp_us || SDL_memcmp(data, sensor->hwdata->data, sizeof(data)) != 0) {
                SDL_PrivateSensorUpdate(sensor, timestamp_us, data, SDL_arraysize(data));
                sensor->hwdata->timestamp_us = timestamp_us;
                SDL_memcpy(sensor->hwdata->data, data, sizeof(data));
            }
        }
    } break;
#endif
    default:
        break;
    }
}

static void SDL_COREMOTION_SensorClose(SDL_Sensor *sensor)
{
    if (sensor->hwdata) {
        switch (sensor->non_portable_type) {
        case SDL_COREMOTION_ACCELEROMETER:
            [SDL_motion_manager stopAccelerometerUpdates];
            break;
        case SDL_COREMOTION_GYROSCOPE:
            [SDL_motion_manager stopGyroUpdates];
            break;
#if TARGET_OS_IOS
        case SDL_COREMOTION_CORRECTED_DEVICE_MOTION:
            [SDL_motion_manager stopDeviceMotionUpdates];
            break;
#endif
        default:
            break;
        }
        SDL_free(sensor->hwdata);
        sensor->hwdata = NULL;
    }
}

static void SDL_COREMOTION_SensorQuit(void)
{
}

SDL_SensorDriver SDL_COREMOTION_SensorDriver = {
    SDL_COREMOTION_SensorInit,
    SDL_COREMOTION_SensorGetCount,
    SDL_COREMOTION_SensorDetect,
    SDL_COREMOTION_SensorGetDeviceName,
    SDL_COREMOTION_SensorGetDeviceType,
    SDL_COREMOTION_SensorGetDeviceNonPortableType,
    SDL_COREMOTION_SensorGetDeviceInstanceID,
    SDL_COREMOTION_SensorOpen,
    SDL_COREMOTION_SensorUpdate,
    SDL_COREMOTION_SensorClose,
    SDL_COREMOTION_SensorQuit,
};

#endif /* SDL_SENSOR_COREMOTION */

/* vi: set ts=4 sw=4 expandtab: */
