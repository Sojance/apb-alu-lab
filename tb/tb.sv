`timescale 1ns/1ps

module TB;

    logic        pclk, presetn;
    logic        psel, penable, pwrite;
    logic [31:0] paddr, pwdata;
    wire  [31:0] prdata;
    wire         pready, pslverr;

    logic [31:0] data_from_device;

    parameter p_device_offset = 32'h7000_0000;

    apb_alu_slave DUT (
        .pclk(pclk), .presetn(presetn),
        .paddr(paddr), .pwdata(pwdata),
        .psel(psel), .penable(penable), .pwrite(pwrite),
        .pready(pready), .pslverr(pslverr), .prdata(prdata)
    );

    apb_master MASTER (
        .pclk(pclk), .presetn(presetn),
        .psel(psel), .penable(penable), .pwrite(pwrite),
        .paddr(paddr), .pwdata(pwdata),
        .pready(pready), .pslverr(pslverr), .prdata(prdata)
    );

    always #10ns pclk = ~pclk;

    int errors = 0;
    task automatic check(input [31:0] got, input [31:0] exp, input string name);
        if (got !== exp) begin
            $error("%s: got 0x%h, exp 0x%h", name, got, exp);
            errors++;
        end else
            $display("[PASS] %s = 0x%h", name, got);
    endtask

    initial begin
        pclk = 0;
        presetn = 1'b1;

        repeat (5) @(posedge pclk);
        presetn = 1'b0;
        repeat (5) @(posedge pclk);
        presetn = 1'b1;
        repeat (5) @(posedge pclk);

        //Инверсия
        $display("\n-- TEST: INVERSE --");
        MASTER.apb_write(p_device_offset + 32'h0, 32'h0000_00FF);
        MASTER.apb_write(p_device_offset + 32'h8, 32'h0000_0004); 
        MASTER.apb_read (p_device_offset + 32'hC, data_from_device);
        check(data_from_device, 32'hFFFF_FF00, "INV 0x000000FF");

        // XOR
        $display("\n-- TEST: XOR --");
        MASTER.apb_write(p_device_offset + 32'h0, 32'hAAAA_AAAA);
        MASTER.apb_write(p_device_offset + 32'h4, 32'h5555_5555);
        MASTER.apb_write(p_device_offset + 32'h8, 32'h0000_0005); 
        MASTER.apb_read (p_device_offset + 32'hC, data_from_device);
        check(data_from_device, 32'hFFFF_FFFF, "XOR AAAAAAAA^55555555");

        //Сравнение равных
        $display("\n-- TEST: CMP EQ --");
        MASTER.apb_write(p_device_offset + 32'h0, 32'h1234_5678);
        MASTER.apb_write(p_device_offset + 32'h4, 32'h1234_5678);
        MASTER.apb_write(p_device_offset + 32'h8, 32'h0000_0006); 
        MASTER.apb_read (p_device_offset + 32'hC, data_from_device);
        check(data_from_device, 32'h0000_0001, "CMP EQ");

        //Сравнение разных
        $display("\n-- TEST: CMP NE --");
        MASTER.apb_write(p_device_offset + 32'h0, 32'h1234_5678);
        MASTER.apb_write(p_device_offset + 32'h4, 32'h8765_4321);
        MASTER.apb_write(p_device_offset + 32'h8, 32'h0000_0006);
        MASTER.apb_read (p_device_offset + 32'hC, data_from_device);
        check(data_from_device, 32'h0000_0000, "CMP NE");

        //A > B
        $display("\n-- TEST: A > B --");
        MASTER.apb_write(p_device_offset + 32'h0, 32'h0000_0005);
        MASTER.apb_write(p_device_offset + 32'h4, 32'h0000_0003);
        MASTER.apb_write(p_device_offset + 32'h8, 32'h0000_0007); 
        MASTER.apb_read (p_device_offset + 32'hC, data_from_device);
        check(data_from_device, 32'h0000_0001, "A>B");

        //Чтение операндов и control 
        $display("\n-- TEST: READBACK --");
        MASTER.apb_read(p_device_offset + 32'h0, data_from_device);
        check(data_from_device, 32'h0000_0005, "RD OP1");
        MASTER.apb_read(p_device_offset + 32'h4, data_from_device);
        check(data_from_device, 32'h0000_0003, "RD OP2");
        MASTER.apb_read(p_device_offset + 32'h8, data_from_device);
        check(data_from_device, 32'h0000_0003, "RD CTRL (start autoclr)");

        //Запись в RESULT (игнор)
        $display("\n-- TEST: WRITE TO RESULT (ignored) --");
        MASTER.apb_write(p_device_offset + 32'hC, 32'hDEAD_BEEF);
        MASTER.apb_read (p_device_offset + 32'hC, data_from_device);
        check(data_from_device, 32'h0000_0001, "RESULT unchanged");

        repeat (10) @(posedge pclk);

        if (errors == 0) $display("\n=== ALL TESTS PASSED ===");
        else             $display("\n=== %0d ERRORS ===", errors);
        $stop;
    end

    initial begin
        #200000;
        $fatal("TIMEOUT");
    end

endmodule