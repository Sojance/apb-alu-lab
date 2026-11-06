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

        // ================= 1. INVERSE =================
        $display("\n-- TEST 1: INVERSE --");
        MASTER.apb_write(p_device_offset + 32'h0, 32'h0000_00FF);
        MASTER.apb_write(p_device_offset + 32'h8, 32'h0000_0004); // op=00
        MASTER.apb_read (p_device_offset + 32'hC, data_from_device);
        check(data_from_device, 32'hFFFF_FF00, "INV 0x000000FF");

        MASTER.apb_write(p_device_offset + 32'h0, 32'h0000_0000);
        MASTER.apb_write(p_device_offset + 32'h8, 32'h0000_0004);
        MASTER.apb_read (p_device_offset + 32'hC, data_from_device);
        check(data_from_device, 32'hFFFF_FFFF, "INV 0x00000000");

        MASTER.apb_write(p_device_offset + 32'h0, 32'hFFFF_FFFF);
        MASTER.apb_write(p_device_offset + 32'h8, 32'h0000_0004);
        MASTER.apb_read (p_device_offset + 32'hC, data_from_device);
        check(data_from_device, 32'h0000_0000, "INV 0xFFFFFFFF");

        // ================= 2. XOR =================
        $display("\n-- TEST 2: XOR --");
        MASTER.apb_write(p_device_offset + 32'h0, 32'hAAAA_AAAA);
        MASTER.apb_write(p_device_offset + 32'h4, 32'h5555_5555);
        MASTER.apb_write(p_device_offset + 32'h8, 32'h0000_0005); // op=01
        MASTER.apb_read (p_device_offset + 32'hC, data_from_device);
        check(data_from_device, 32'hFFFF_FFFF, "XOR AAAAAAAA^55555555");

        MASTER.apb_write(p_device_offset + 32'h0, 32'h1234_5678);
        MASTER.apb_write(p_device_offset + 32'h4, 32'h1234_5678);
        MASTER.apb_write(p_device_offset + 32'h8, 32'h0000_0005);
        MASTER.apb_read (p_device_offset + 32'hC, data_from_device);
        check(data_from_device, 32'h0000_0000, "XOR A^A");

        // ================= 3. CMP EQ =================
        $display("\n-- TEST 3: CMP EQ --");
        MASTER.apb_write(p_device_offset + 32'h0, 32'h1234_5678);
        MASTER.apb_write(p_device_offset + 32'h4, 32'h1234_5678);
        MASTER.apb_write(p_device_offset + 32'h8, 32'h0000_0006); // op=10
        MASTER.apb_read (p_device_offset + 32'hC, data_from_device);
        check(data_from_device, 32'h0000_0001, "CMP EQ (equal)");

        MASTER.apb_write(p_device_offset + 32'h0, 32'h1234_5678);
        MASTER.apb_write(p_device_offset + 32'h4, 32'h8765_4321);
        MASTER.apb_write(p_device_offset + 32'h8, 32'h0000_0006);
        MASTER.apb_read (p_device_offset + 32'hC, data_from_device);
        check(data_from_device, 32'h0000_0000, "CMP EQ (not equal)");

        // ================= 4. CMP GT =================
        $display("\n-- TEST 4: CMP GT --");
        MASTER.apb_write(p_device_offset + 32'h0, 32'h0000_0005);
        MASTER.apb_write(p_device_offset + 32'h4, 32'h0000_0003);
        MASTER.apb_write(p_device_offset + 32'h8, 32'h0000_0007); // op=11
        MASTER.apb_read (p_device_offset + 32'hC, data_from_device);
        check(data_from_device, 32'h0000_0001, "A > B");

        MASTER.apb_write(p_device_offset + 32'h0, 32'h0000_0003);
        MASTER.apb_write(p_device_offset + 32'h4, 32'h0000_0005);
        MASTER.apb_write(p_device_offset + 32'h8, 32'h0000_0007);
        MASTER.apb_read (p_device_offset + 32'hC, data_from_device);
        check(data_from_device, 32'h0000_0000, "A < B");

        MASTER.apb_write(p_device_offset + 32'h0, 32'h0000_0005);
        MASTER.apb_write(p_device_offset + 32'h4, 32'h0000_0005);
        MASTER.apb_write(p_device_offset + 32'h8, 32'h0000_0007);
        MASTER.apb_read (p_device_offset + 32'hC, data_from_device);
        check(data_from_device, 32'h0000_0000, "A == B (not >)");

        // ================= 5. READBACK =================
        $display("\n-- TEST 5: READBACK --");
        MASTER.apb_write(p_device_offset + 32'h0, 32'hDEAD_BEEF);
        MASTER.apb_write(p_device_offset + 32'h4, 32'hCAFE_F00D);
        MASTER.apb_read (p_device_offset + 32'h0, data_from_device);
        check(data_from_device, 32'hDEAD_BEEF, "RD OP1");
        MASTER.apb_read (p_device_offset + 32'h4, data_from_device);
        check(data_from_device, 32'hCAFE_F00D, "RD OP2");

        // Явно запускаем INV, чтобы зафиксировать control в известном состоянии
        MASTER.apb_write(p_device_offset + 32'h8, 32'h0000_0004); // start=1, op=00
        MASTER.apb_read (p_device_offset + 32'h8, data_from_device);
        check(data_from_device, 32'h0000_0000, "RD CTRL (start autoclr)");

        // ================= 6. Запись в RESULT игнорируется =================
        $display("\n-- TEST 6: WRITE TO RESULT (ignored) --");
        MASTER.apb_write(p_device_offset + 32'h0, 32'h0000_0001);
        MASTER.apb_write(p_device_offset + 32'h8, 32'h0000_0004); // INV -> 0xFFFFFFFE
        MASTER.apb_write(p_device_offset + 32'hC, 32'hDEAD_BEEF); // попытка перезаписи
        MASTER.apb_read (p_device_offset + 32'hC, data_from_device);
        check(data_from_device, 32'hFFFF_FFFE, "RESULT unchanged");

        // ================= 7. Автосброс start =================
        $display("\n-- TEST 7: START AUTOCLEAR --");
        MASTER.apb_write(p_device_offset + 32'h0, 32'h0000_0007);
        MASTER.apb_write(p_device_offset + 32'h8, 32'h0000_0004); // INV
        MASTER.apb_read (p_device_offset + 32'h8, data_from_device);
        check(data_from_device, 32'h0000_0000, "CTRL after start");

        // ================= 8. RESET посреди работы =================
        $display("\n-- TEST 8: RESET --");
        MASTER.apb_write(p_device_offset + 32'h0, 32'hFFFF_FFFF);
        MASTER.apb_write(p_device_offset + 32'h4, 32'hFFFF_FFFF);
        presetn = 1'b0;
        repeat (3) @(posedge pclk);
        presetn = 1'b1;
        repeat (3) @(posedge pclk);
        MASTER.apb_read (p_device_offset + 32'h0, data_from_device);
        check(data_from_device, 32'h0000_0000, "OP1 after reset");
        MASTER.apb_read (p_device_offset + 32'h4, data_from_device);
        check(data_from_device, 32'h0000_0000, "OP2 after reset");
        MASTER.apb_read (p_device_offset + 32'h8, data_from_device);
        check(data_from_device, 32'h0000_0000, "CTRL after reset");
        MASTER.apb_read (p_device_offset + 32'hC, data_from_device);
        check(data_from_device, 32'h0000_0000, "RESULT after reset");

        repeat (10) @(posedge pclk);

        if (errors == 0) $display("\n=== ALL TESTS PASSED (18 checks) ===");
        else             $display("\n=== %0d ERRORS ===", errors);
        $finish;
    end

    initial begin
        #500000;
        $fatal("TIMEOUT");
    end

endmodule