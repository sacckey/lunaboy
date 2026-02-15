<br>
<p align="center">
  <img src="https://raw.githubusercontent.com/sacckey/lunaboy/535efa43bafc54f08578955ffb69c0d7e59299b1/resource/logo/logo.svg" width="480px">
</p>
<br>

A Game Boy emulator written in MoonBit

**[Try the demo in your browser!](https://sacckey.github.io/lunaboy/)** - Powered by WasmGC

## Screenshots
<div align="center">
  <img src="https://raw.githubusercontent.com/sacckey/lunaboy/refs/heads/main/resource/screenshots/tobu.png" width="400px"/>
</div>

## Run on Native

Native backend requires [SDL3](https://github.com/libsdl-org/SDL/blob/main/INSTALL.md).

```sh
moon run ./native/cmd/main --manifest-path ./native/moon.mod.json <rom_path>
```

## Run on WasmGC

From the `docs` directory, start a local HTTP server:

```sh
python3 -m http.server 8080
```

Then open `http://localhost:8080` in your browser.

## Controls

| Key   | Button |
| :---: | :----: |
| `W`   | ↑      |
| `A`   | ←      |
| `S`   | ↓      |
| `D`   | →      |
| `J`   | A      |
| `K`   | B      |
| `U`   | Select |
| `I`   | Start  |
