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

#ifndef SDL_uikit_rawtouch_h_
#define SDL_uikit_rawtouch_h_

#include "SDL_stdinc.h"

#include "begin_code.h"
#ifdef __cplusplus
extern "C" {
#endif

typedef enum IOSRawTouchPhase
{
    IOSRawTouchPhaseBegan = 0,
    IOSRawTouchPhaseMoved = 1,
    IOSRawTouchPhaseEnded = 2,
    IOSRawTouchPhaseCancelled = 3,
} IOSRawTouchPhase;

typedef struct IOSRawTouchEvent
{
    Sint64 fingerId;
    float normalizedX;
    float normalizedY;
    float pressure;
    Uint64 timestampMicros;
    IOSRawTouchPhase phase;
} IOSRawTouchEvent;

typedef void (SDLCALL *IOSRawTouchEventSink)(const IOSRawTouchEvent *event,
                                             void *context);

extern DECLSPEC void SDLCALL IOSPushRawTouchEvent(IOSRawTouchPhase phase,
                                                  Sint64 fingerId,
                                                  float normalizedX,
                                                  float normalizedY,
                                                  float pressure,
                                                  Uint64 timestampMicros);
extern DECLSPEC size_t SDLCALL IOSPopRawTouchEvents(IOSRawTouchEvent *buffer,
                                                    size_t maxEvents);
extern DECLSPEC void SDLCALL
IOSSetRawTouchEventSink(IOSRawTouchEventSink sink, void *context);

#ifdef __cplusplus
}
#endif
#include "close_code.h"

#endif /* SDL_uikit_rawtouch_h_ */
