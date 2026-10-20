`timescale 1ns/1ps

module tb_game;

    reg clk = 0;
    reg [3:0] switches = 4'b0000;

    wire [3:0] leds;

    wire s1a, s1b, s1c, s1d, s1e, s1f, s1g;
    wire s2a, s2b, s2c, s2d, s2e, s2f, s2g;
    wire spi_miso;

    integer correctas = 0;
    integer error_probado = 0;

    always #20 clk = ~clk;


    // En la FPGA real:
    // TenthCycles = 2.500.000
    //
    // En simulacion usamos 100 para acelerar.
    pochoco_soc #(
        .MemFile("sw/game.hex"),
        .TenthCycles(100)
    ) dut (
        .i_Clk(clk),

        .o_LED(leds),
        .i_Switch(switches),

        .o_Segment1_A(s1a),
        .o_Segment1_B(s1b),
        .o_Segment1_C(s1c),
        .o_Segment1_D(s1d),
        .o_Segment1_E(s1e),
        .o_Segment1_F(s1f),
        .o_Segment1_G(s1g),

        .o_Segment2_A(s2a),
        .o_Segment2_B(s2b),
        .o_Segment2_C(s2c),
        .o_Segment2_D(s2d),
        .o_Segment2_E(s2e),
        .o_Segment2_F(s2f),
        .o_Segment2_G(s2g),

        .i_SPI_SCLK(1'b0),
        .i_SPI_MOSI(1'b0),
        .i_SPI_CS_n(1'b1),
        .o_SPI_MISO(spi_miso)
    );


    task press_button;
        input [3:0] button;
        begin

            // Tiempo de reaccion simulado
            repeat (250) @(posedge clk);

            switches = button;

            repeat (20) @(posedge clk);

            switches = 4'b0000;

            repeat (20) @(posedge clk);

        end
    endtask


    initial begin

        $display("==============================");
        $display(" TEST COMPLETO JUEGO");
        $display("==============================");

        // Esperar reset interno
        repeat (70000) @(posedge clk);

        // Pulsacion inicial
        switches = 4'b0001;
        repeat (20) @(posedge clk);
        switches = 4'b0000;


        while (correctas < 10) begin

            // Fase de espera
            wait (leds == 4'b1111);

            $display(
                "Ronda %0d: LEDs 1111",
                correctas + 1
            );

            // Esperar LED objetivo
            wait (
                leds == 4'b0001 ||
                leds == 4'b0010 ||
                leds == 4'b0100 ||
                leds == 4'b1000
            );

            $display("Objetivo: %b", leds);


            // Probar UN error en la tercera ronda
            if ((correctas == 2) && (error_probado == 0)) begin

                error_probado = 1;

                case (leds)
                    4'b0001: press_button(4'b0010);
                    4'b0010: press_button(4'b0100);
                    4'b0100: press_button(4'b1000);
                    4'b1000: press_button(4'b0001);
                endcase

                wait (dut.u_periph.digit_q == 8'hEE);

                $display("Error detectado correctamente.");

            end

            else begin

                case (leds)
                    4'b0001: press_button(4'b0001);
                    4'b0010: press_button(4'b0010);
                    4'b0100: press_button(4'b0100);
                    4'b1000: press_button(4'b1000);
                endcase

                correctas = correctas + 1;

                $display(
                    "Respuesta correcta (%0d/10)",
                    correctas
                );

            end

        end


        // Dar tiempo para calcular promedio
        repeat (300) @(posedge clk);


        $display("");
        $display("==============================");
        $display(" RESULTADO FINAL");
        $display("==============================");

        $display("Correctas = %0d", correctas);
        $display("Error probado = %0d", error_probado);
        $display("LEDs finales = %b", leds);
        $display(
            "Display final = %h",
            dut.u_periph.digit_q
        );


        if (
            correctas == 10 &&
            error_probado == 1 &&
            leds == 4'b0000
        )
            $display("TEST OK: JUEGO COMPLETO FUNCIONA.");
        else
            $display("TEST ERROR.");

        $finish;

    end


    // Evitar simulacion infinita
    initial begin

        repeat (200000) @(posedge clk);

        $display("TIMEOUT GENERAL.");
        $finish;

    end

endmodule
