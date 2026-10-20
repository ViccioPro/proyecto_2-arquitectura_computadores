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

Desde la raíz del repositorio:

```bash
python assembler_v1.py pochoco_soc/sw/game.s pochoco_soc/sw/game.hex
```

El assembler utilizado fue desarrollado para el proyecto y genera una palabra de 32 bits en hexadecimal por línea.

## Síntesis y programación

El top-level del proyecto es `game_top` y carga `sw/game.hex`.

En sistemas con GNU Make instalado, desde la carpeta `pochoco_soc`:

```bash
make all
```

También se puede realizar el flujo manualmente utilizando OSS CAD Suite.

### Síntesis

```bash
yosys -p "read_verilog rtl/game_top.v rtl/pochoco_soc.v rtl/pochoco_periph.v rtl/pochoco_ram.v rtl/pochoco_spi_slave.v rtl/espino_core/espino_alu.v rtl/espino_core/espino_controller.v rtl/espino_core/espino_core.v rtl/espino_core/espino_decoder.v rtl/espino_core/espino_id_stage.v rtl/espino_core/espino_if_stage.v rtl/espino_core/espino_load_store_unit.v rtl/espino_core/espino_register_file.v; synth_ice40 -top game_top -json game_top.json; stat"
```

### Place & route

```bash
nextpnr-ice40 --hx1k --package vq100 --json game_top.json --pcf goboard.pcf --asc game_top.asc
```

### Generar bitstream

```bash
icepack game_top.asc game_top.bin
```

### Programar la FPGA

```bash
iceprog game_top.bin
```

## Simulación

El archivo `pochoco_soc/tb_game.v` realiza una simulación automática de una partida completa.

La prueba verifica:

- 10 respuestas correctas.
- Selección de los LEDs objetivo.
- Medición del tiempo de reacción.
- Una respuesta incorrecta.
- Reinicio de la ronda incorrecta sin perder las rondas correctas anteriores.
- Cálculo del promedio final.

Para acelerar la simulación se reduce el parámetro `TenthCycles`. En la FPGA el valor utilizado es de 2.500.000 ciclos por décima de segundo.