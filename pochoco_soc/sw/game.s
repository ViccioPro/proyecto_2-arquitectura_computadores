.section .text
.global _start

# ============================================================
# Juego de reflejos - Pochoco SoC
#
# MMIO:
# 0x80000000 -> displays
# 0x80000004 -> LEDs
# 0x80000008 -> botones
# 0x8000000C -> contador de ciclos
# 0x80000010 -> contador de decimas
#
# 25 MHz
# 2.500.000 ciclos = 0,1 segundos
# ============================================================

_start:

    # x2 = base de perifericos
    lui  x2, 0x80000

    # x3 = rondas correctas
    # x4 = suma de tiempos
    addi x3, x0, 0
    addi x4, x0, 0

    # Apagar LEDs y display
    sw   x0, 4(x2)
    sw   x0, 0(x2)

    # Para encender los LEDs del display en 11
    # lo usamos para debugguear el estado al que llega
    #addi x1, x0, 0x11
    #sw   x1, 0(x2)

# ============================================================
# Esperar una pulsacion para comenzar
# ============================================================

wait_start_press:

    lw   x1, 8(x2)
    andi x1, x1, 15
    beq  x1, x0, wait_start_press

    # Para encender los LEDs del display en 22
    # lo usamos para debugguear el estado al que llega
    #addi x1, x0, 0x22
    #sw   x1, 0(x2)

    # Tomamos una semilla dependiente del instante
    # en que el jugador inicio la partida.
    lw   x14, 12(x2)


wait_start_release:

    lw   x1, 8(x2)
    andi x1, x1, 15
    bne  x1, x0, wait_start_release


# ============================================================
# INICIO DE RONDA
# ============================================================

round_start:

    # Esperar botones liberados
    lw   x1, 8(x2)
    andi x1, x1, 15
    bne  x1, x0, round_start

    # Encender los cuatro LEDs
    addi x1, x0, 15
    sw   x1, 4(x2)

    # Guardar instante inicial
    lw   x6, 16(x2)

    # 30 decimas = 3 segundos
    addi x12, x0, 30


wait_three_seconds:

    lw   x7, 16(x2)

    # decimas transcurridas
    sub  x7, x7, x6

    # seguir mientras x7 < 30
    bltu x7, x12, wait_three_seconds


# ============================================================
# Esperar que no haya botones presionados
# ============================================================

wait_before_target:

    lw   x1, 8(x2)
    andi x1, x1, 15
    bne  x1, x0, wait_before_target


# ============================================================
# Elegir objetivo pseudoaleatorio
# ============================================================

    # Mezclar semilla con contador actual,
    # ronda y tiempos anteriores.
    lw   x8, 12(x2)

    xor  x14, x14, x8
    xor  x14, x14, x4
    xor  x14, x14, x3
    xori x14, x14, 1445

    andi x8, x14, 3

    beq  x8, x0, target_0

    addi x1, x0, 1
    beq  x8, x1, target_1

    addi x1, x0, 2
    beq  x8, x1, target_2

    # Objetivo 3
    addi x5, x0, 8
    jal  x0, target_ready


target_0:

    addi x5, x0, 1
    jal  x0, target_ready


target_1:

    addi x5, x0, 2
    jal  x0, target_ready


target_2:

    addi x5, x0, 4


# ============================================================
# Mostrar objetivo y empezar cronometro
# ============================================================

target_ready:

    sw   x5, 4(x2)

    # instante inicial en decimas
    lw   x6, 16(x2)


# ============================================================
# Esperar pulsacion
# ============================================================

wait_button:

    lw   x1, 8(x2)
    andi x1, x1, 15

    beq  x1, x0, wait_button

    # instante de pulsacion
    lw   x7, 16(x2)

    # Debe coincidir exactamente con el objetivo
    bne  x1, x5, wrong_button


# ============================================================
# RESPUESTA CORRECTA
# ============================================================

    # x9 = tiempo de respuesta en decimas
    sub  x9, x7, x6

    # Acumular tiempos
    add  x4, x4, x9

    # Sumar ronda correcta
    addi x3, x3, 1


# ============================================================
# Limitar tiempo mostrado a 99
# ============================================================

    slti x13, x9, 100
    bne  x13, x0, time_under_100

    addi x9, x0, 99


time_under_100:

    # x10 = decenas
    addi x10, x0, 0


# ============================================================
# Convertir numero a BCD
# ============================================================

time_bcd_loop:

    slti x13, x9, 10
    bne  x13, x0, time_bcd_done

    addi x9, x9, -10
    addi x10, x10, 1

    jal  x0, time_bcd_loop


time_bcd_done:

    # decenas * 16 sin shifts
    add  x11, x10, x10
    add  x11, x11, x11
    add  x11, x11, x11
    add  x11, x11, x11

    # sumar unidades
    add  x11, x11, x9

    # mostrar resultado
    sw   x11, 0(x2)


# ============================================================
# ¿Terminamos las 10 rondas?
# ============================================================

    addi x1, x0, 10
    beq  x3, x1, game_finished

    jal  x0, round_start


# ============================================================
# RESPUESTA INCORRECTA
# ============================================================

wrong_button:

    # EE
    addi x1, x0, 238
    sw   x1, 0(x2)

    # LEDs apagados
    sw   x0, 4(x2)

    # La ronda NO se suma
    # El tiempo NO se suma
    jal  x0, round_start


# ============================================================
# FIN DEL JUEGO
# ============================================================

game_finished:

    sw   x0, 4(x2)

    # promedio = suma / 10
    # Sumamos 5 para redondear.
    add  x11, x4, x0
    addi x11, x11, 5

    # x9 = promedio
    addi x9, x0, 0


average_loop:

    slti x13, x11, 10
    bne  x13, x0, average_done

    addi x11, x11, -10
    addi x9, x9, 1

    jal  x0, average_loop


average_done:

    # Maximo mostrado = 99
    slti x13, x9, 100
    bne  x13, x0, average_under_100

    addi x9, x0, 99


average_under_100:

    addi x10, x0, 0


average_bcd_loop:

    slti x13, x9, 10
    bne  x13, x0, average_bcd_done

    addi x9, x9, -10
    addi x10, x10, 1

    jal  x0, average_bcd_loop


average_bcd_done:

    # decenas * 16
    add  x11, x10, x10
    add  x11, x11, x11
    add  x11, x11, x11
    add  x11, x11, x11

    # + unidades
    add  x11, x11, x9

    sw   x11, 0(x2)


# ============================================================
# Mantener promedio en pantalla
# ============================================================

finished:

    jal  x0, finished
