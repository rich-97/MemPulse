# MemPulse

Punto de color en la barra de menú que indica la **presión de memoria** del
sistema, con el mismo semáforo que Activity Monitor:

- 🟢 **verde** — normal, el Mac no está tirando de swap de forma agresiva
- 🟡 **amarillo** — presión elevada
- 🔴 **rojo** — presión crítica, cierra algo

Al abrir el menú se ve la swap usada, la RAM usada/comprimida y las 5 apps que
más memoria consumen, con un botón para cerrarlas.

Pensado para cuidar la salud del SSD evitando swap innecesaria.

## Compilar

Necesita [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).
El `.xcodeproj` se genera, no se versiona.

```sh
xcodegen generate
open MemPulse.xcodeproj      # y Cmd+R en Xcode
```

O desde terminal:

```sh
xcodebuild -scheme MemPulse -destination 'platform=macOS' build
xcodebuild test -scheme MemPulse -destination 'platform=macOS'
```

El binario queda en `~/Library/Developer/Xcode/DerivedData/MemPulse-*/Build/Products/`.
Arrástralo a `/Applications` para dejarlo fijo.

## Cómo funciona

- Color: `DispatchSource.makeMemoryPressureSource` — el kernel avisa al cambiar,
  sin sondeo.
- Swap: `sysctl vm.swapusage`.
- RAM: `host_statistics64` (`HOST_VM_INFO64`).
- Top procesos: `/bin/ps -axo pid=,rss=,comm=` cada 5 s.

Sin App Sandbox (lanza `ps`). Sin dependencias de terceros en runtime.

## Probar la presión de memoria

```sh
sudo memory_pressure -l warn     -S -s 15   # → amarillo
sudo memory_pressure -l critical -S -s 15   # → rojo
```

El punto vuelve a verde al terminar.
