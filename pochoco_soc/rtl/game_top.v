module game_top (
    input  wire       i_Clk,

    // UART
    input  wire       i_UART_RX,
    output wire       o_UART_TX,

    // LEDs y botones
    output wire [3:0] o_LED,
    input  wire [3:0] i_Switch,

    // Display 1
    output wire o_Segment1_A,
    output wire o_Segment1_B,
    output wire o_Segment1_C,
    output wire o_Segment1_D,
    output wire o_Segment1_E,
    output wire o_Segment1_F,
    output wire o_Segment1_G,

    // Display 2
    output wire o_Segment2_A,
    output wire o_Segment2_B,
    output wire o_Segment2_C,
    output wire o_Segment2_D,
    output wire o_Segment2_E,
    output wire o_Segment2_F,
    output wire o_Segment2_G,

    // SPI
    input  wire i_SPI_CS_n,
    input  wire i_SPI_MOSI,
    input  wire i_SPI_SCLK,
    output wire o_SPI_MISO
);

    // UART no se utiliza en este proyecto
    assign o_UART_TX = 1'b1;

    pochoco_soc #(
        .MemFile("sw/game.hex")
    ) u_pochoco (
        .i_Clk(i_Clk),

        .o_LED(o_LED),
        .i_Switch(i_Switch),

        .o_Segment1_A(o_Segment1_A),
        .o_Segment1_B(o_Segment1_B),
        .o_Segment1_C(o_Segment1_C),
        .o_Segment1_D(o_Segment1_D),
        .o_Segment1_E(o_Segment1_E),
        .o_Segment1_F(o_Segment1_F),
        .o_Segment1_G(o_Segment1_G),

        .o_Segment2_A(o_Segment2_A),
        .o_Segment2_B(o_Segment2_B),
        .o_Segment2_C(o_Segment2_C),
        .o_Segment2_D(o_Segment2_D),
        .o_Segment2_E(o_Segment2_E),
        .o_Segment2_F(o_Segment2_F),
        .o_Segment2_G(o_Segment2_G),

        .i_SPI_CS_n(i_SPI_CS_n),
        .i_SPI_MOSI(i_SPI_MOSI),
        .i_SPI_SCLK(i_SPI_SCLK),
        .o_SPI_MISO(o_SPI_MISO)
    );

endmodule