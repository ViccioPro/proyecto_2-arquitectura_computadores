module game_top (... puertos de la Go Board ...);
  pochoco_soc #(.MemFile("sw/game.hex")) u_pochoco (
  .i_Clk(i_Clk),
        // conectar LEDs, botones, displays y SPI
        // A PURA FE SE VA A LOGRAR
);


endmodule
