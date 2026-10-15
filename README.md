# MemPulse

Un punto de color en la barra de menú de macOS que muestra la **presión de
memoria** del sistema, el mismo semáforo que usa Activity Monitor:

| Punto | Presión | Qué significa |
|:-----:|---------|---------------|
| 🟢 | Normal   | El Mac va sobrado de memoria. |
| 🟡 | Elevada  | Empieza a comprimir y a tirar de swap. |
| 🔴 | Crítica  | Swap intensiva: cierra algo. Recibes una notificación. |

Al abrir el menú ves:

- Swap usada, RAM usada y RAM comprimida.
- Las **5 apps que más memoria usan**, sumando todos sus procesos
  (Chrome cuenta con todos sus *Helpers* y *Renderers*, no por separado).
- Un botón **Cerrar** por app. Mantén **⌥ Option** al pulsarlo para forzar el cierre.
- Opción para abrir MemPulse al iniciar sesión.

Pensado para cuidar el SSD evitando swap innecesaria, sin abrir Activity Monitor.

## Requisitos

- macOS 14 (Sonoma) o posterior.
- Xcode 15+ y [XcodeGen](https://github.com/yonaskolb/XcodeGen) para compilar.

## Instalación

```sh
brew install xcodegen
git clone https://github.com/rich-97/macos-mem-pulse.git
cd macos-mem-pulse
xcodegen generate
xcodebuild -scheme MemPulse -configuration Release -destination 'platform=macOS' build
```

El `.app` queda en
`~/Library/Developer/Xcode/DerivedData/MemPulse-*/Build/Products/Release/MemPulse.app`.
Cópialo a `/Applications` y ábrelo. También puedes abrir `MemPulse.xcodeproj` en
Xcode y pulsar ⌘R.

La primera vez macOS pedirá permiso para enviar notificaciones (solo se usan
cuando la presión pasa a crítica).

## Cómo funciona

| Dato | Fuente |
|------|--------|
| Color del punto | `DispatchSource.makeMemoryPressureSource`: el kernel avisa al cambiar, sin sondeo. Al arrancar se lee el estado actual con `sysctl kern.memorystatus_vm_pressure_level`. |
| Swap | `sysctl vm.swapusage` |
| RAM | `host_statistics64` (`HOST_VM_INFO64`) |
| Top apps | `/bin/ps -axo pid=,rss=,comm=` cada 5 s, agrupado por el `.app` contenedor |

Sin dependencias de terceros. Sin App Sandbox, porque necesita lanzar `/bin/ps`.

## Desarrollo

`project.yml` es la fuente de verdad; el `.xcodeproj` se genera y no se versiona.
Tras añadir o quitar archivos, vuelve a ejecutar `xcodegen generate`.

```sh
xcodebuild test -scheme MemPulse -destination 'platform=macOS'
```

Para ver los colores sin llenar la RAM de verdad:

```sh
sudo memory_pressure -l warn     -S -s 15   # → amarillo
sudo memory_pressure -l critical -S -s 15   # → rojo + notificación
```

El punto vuelve a verde al terminar.
