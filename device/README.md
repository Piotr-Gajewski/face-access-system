# device

Door reader software. It reads the camera and the presence sensor, shows the user what to do and switches the lock relay, but makes no decisions: it carries out commands from `access-service`, keeps no user data and opens no ports (it connects to the server itself over WSS).

The same program runs on a PC as the **reader simulator**. Image sources (Raspberry Pi camera, USB webcam, video file, recorded session) and hardware (GPIO pins or a console stand-in) are separate, so the simulator speaks exactly the device protocol. It is used for development, CI tests, replaying recorded sessions and injection attacks.

| | |
|---|---|
| Technology | Python 3.12; on the device Raspberry Pi OS Lite (64-bit) on a Raspberry Pi Zero 2 W with a NoIR camera and a presence radar |
| Status | Planned. The simulator comes first; the physical reader later. |
