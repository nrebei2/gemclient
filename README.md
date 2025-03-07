A simple graphical client for the plain-text [Gemini protocol](https://geminiprotocol.net/) written in zig. UI is done with [clay](https://github.com/nicbarker/clay), and rendering with [raylib](https://github.com/raysan5/raylib).

## Screenshots

![gemini://carcosa.net](screenshots/Screenshot%202025-03-07%20at%201.39.39 PM.png)
![gemini://geminiprotocol.net/history](screenshots/Screenshot%202025-03-07%20at%201.29.57 PM.png)

## Build and Run

Building requires a zig version >= 0.14.0. 

```sh
zig build && ./zig-out/bin/zig-gemini
```
