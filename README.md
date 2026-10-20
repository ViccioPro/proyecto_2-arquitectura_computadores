# Proyecto 2 - Arquitectura de Computadores

Juego de reflejos desarrollado en Assembly para el Espino Core sobre Pochoco SoC y FPGA Lattice iCE40 HX1K.

## Funcionamiento

En cada ronda:

1. Los cuatro LEDs se encienden durante al menos 3 segundos.
2. Se selecciona pseudoaleatoriamente uno de los cuatro LEDs.
3. El jugador debe presionar el botón correspondiente.
4. Se mide el tiempo de reacción en décimas de segundo.
5. Si se presiona un botón incorrecto, se muestra `EE` y se reinicia la ronda actual.
6. Después de 10 respuestas correctas se muestra el tiempo promedio.

## Mapa de periféricos

| Dirección | Periférico |
|---|---|
| `0x80000000` | Displays de 7 segmentos |
| `0x80000004` | LEDs |
| `0x80000008` | Botones |
| `0x8000000C` | Contador de ciclos |
| `0x80000010` | Contador de décimas |

La Go Board trabaja a 25 MHz.

Por lo tanto:

- 25.000.000 ciclos = 1 segundo
- 2.500.000 ciclos = 0,1 segundos
- 30 décimas = 3 segundos

## Generar game.hex

Desde la carpeta `pochoco_soc`:

```bash
python3 assembler_v1.py sw/game.s sw/game.hex
```

El assembler utilizado fue desarrollado para el proyecto y genera una palabra de 32 bits en hexadecimal por línea.

**Nota:** el Makefile genera automáticamente `game.hex` cuando se modifica `game.s` o `assembler_v1.py`, por lo que no es necesario ejecutar este comando manualmente al utilizar `make`.

## Síntesis y programación

El top-level del proyecto es `game_top` y carga `sw/game.hex`.

En sistemas con GNU Make, Python 3 y OSS CAD Suite instalados, desde la carpeta `pochoco_soc`:

```bash
make all
```

Este comando ejecuta automáticamente el ensamblador cuando corresponde, realiza la síntesis y el place & route, genera el bitstream y programa la FPGA mediante `iceprog`.

Si solamente se desea compilar el proyecto y generar el bitstream, sin programar la FPGA:

```bash
make game_top.bin
```

Este comando permite verificar la compilación del proyecto sin necesidad de tener la Go Board conectada.

También se puede realizar el flujo manualmente utilizando OSS CAD Suite.

### Síntesis

```bash
yosys -p "read_verilog rtl/game_top.v rtl/pochoco_soc.v rtl/pochoco_periph.v rtl/pochoco_ram.v rtl/pochoco_spi_slave.v rtl/espino_core/espino_alu.v rtl/espino_core/espino_controller.v rtl/espino_core/espino_core.v rtl/espino_core/espino_decoder.v rtl/espino_core/espino_id_stage.v rtl/espino_core/espino_if_stage.v rtl/espino_core/espino_load_store_unit.v rtl/espino_core/espino_register_file.v; synth_ice40 -top game_top -json game_top.json; stat"
```

### Place & route

```bash
nextpnr-ice40 --hx1k --package vq100 --freq 25 --json game_top.json --pcf goboard.pcf --asc game_top.asc
```

El parámetro `--freq 25` establece una frecuencia objetivo de 25 MHz para verificar la temporización del diseño.

### Generar bitstream

```bash
icepack game_top.asc game_top.bin
```

### Programar la FPGA

```bash
iceprog game_top.bin
```

Para este último paso se requiere que la Go Board esté conectada y sea reconocida por el sistema.

## Inicialización del procesador

Durante las pruebas físicas se detectó un problema de inicialización al encender la FPGA.

El contador de Power-On Reset original utilizaba 4 bits, lo que proporcionaba un tiempo de inicialización demasiado corto.

Para corregirlo, se amplió el contador a 16 bits en `rtl/pochoco_soc.v`:

```verilog
reg [15:0] por_cnt = 16'b0;
```

Con esta modificación, el RESET permanece activo durante aproximadamente 2,62 ms a 25 MHz, permitiendo un arranque más confiable del procesador.

La corrección fue comprobada mediante pruebas de encendido y reinicio de la FPGA física.

## Simulación

El archivo `pochoco_soc/tb_game.v` contiene un banco de pruebas para simular una partida completa.

La prueba está diseñada para verificar:

- 10 respuestas correctas.
- Selección de los LEDs objetivo.
- Medición del tiempo de reacción.
- Una respuesta incorrecta.
- Reinicio de la ronda incorrecta sin perder las rondas correctas anteriores.
- Cálculo del promedio final.

Para acelerar la simulación se reduce el parámetro `TenthCycles`. En la FPGA el valor utilizado es de 2.500.000 ciclos por décima de segundo.

**Nota:** tras ampliar el Power-On Reset a 16 bits, es necesario adaptar la espera inicial del testbench antes de volver a ejecutar la simulación de la versión final.

### Imagen de confirmación de la simulación del testbench.

Para confirmar el correcto funcionamiento del juego, se utiliza `iverilog` y `vvp`, estando en la carpeta de `pochoco_soc`. El resultado de la simulación se puede observar en la imagen a continuación:

<img width="1142" height="814" alt="Foto_testbench_proyecto_2" src="https://github.com/user-attachments/assets/066ee148-7277-411e-a66f-a22b6e5ac1b7" />
