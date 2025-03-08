A simple graphical client for the plain-text [Gemini protocol](https://geminiprotocol.net/) written in zig. UI is done with [clay](https://github.com/nicbarker/clay), and rendering with [raylib](https://github.com/raysan5/raylib).

## Screenshots

![gemini://carcosa.net](screenshots/Screenshot%202025-03-07%20at%201.39.39 PM.png)
![gemini://geminiprotocol.net/history](screenshots/Screenshot%202025-03-07%20at%201.29.57 PM.png)

## Build and Run

Building requires a zig version >= 0.14.0. 

```sh
zig build && ./zig-out/bin/zig-gemini
```

## Settings

Currently, you can change the initial URL along with colors for most ui elements by creating a file at `~/.config/gemclient/settings.toml`. Below are the keys currently supported with their default values. You can also use hex codes (`#RRGGBB`) to describe colors.

```toml
[general]
start_url = "gemini://geminiprotocol.net/"

[colors]
h1 = "purple"
h2 = "green"
h3 = "orange"
text = "white"
background = "gray"
top_panel = "blue"
[colors.list]
    text = "green"
    bullet = "orange"
[colors.address_bar]
    text = "light_gray"
    background = "dark_gray"
[colors.quote]
    text="white"
    background="dark_gray"
[colors.link]
    text="blue"
    hovered="light_blue"
[colors.preformat]
    text="white"
    background="dark_gray"
```