// Testbench верхнего уровня для APB ALU Slave (вариант 7).
// Содержит:
//  генератор тактового сигнала;
//  формирование сброса;
//  экземпляры мастера и слейва;
//  набор направленных тестов (18 проверок) для всех операций,
//  граничных случаев, автосброса start и сброса посреди работы.
`timescale 1ns/1ps

module TB;

    //Сигналы шины APB
    logic        pclk, presetn;
    logic        psel, penable, pwrite;
    logic [31:0] paddr, pwdata;
    wire  [31:0] prdata;
    wire         pready, pslverr;

    logic [31:0] data_from_device;

    // Базовый адрес
    parameter p_device_offset = 32'h7000_0000;

    // Проверяемое устройство
    apb_alu_slave DUT (
        .pclk(pclk), .presetn(presetn),
        .paddr(paddr), .pwdata(pwdata),
        .psel(psel), .penable(penable), .pwrite(pwrite),
        .pready(pready), .pslverr(pslverr), .prdata(prdata)
    );

    //Мастер
    apb_master MASTER (
        .pclk(pclk), .presetn(presetn),
        .psel(psel), .penable(penable), .pwrite(pwrite),
        .paddr(paddr), .pwdata(pwdata),
        .pready(pready), .pslverr(pslverr), .prdata(prdata)
    );

    // Период тактового сигнала — 20 нс
    always #10ns pclk = ~pclk;

    //Счётчик ошибок и задача проверки
    int errors = 0;

    task automatic check(input [31:0] got, input [31:0] exp, input string name);
        if (got !== exp) begin
            $error("%s: got 0x%h, exp 0x%h", name, got, exp);
            errors++;
        end else
            $display("[PASS] %s = 0x%h", name, got);
    endtask

    initial begin
        //Начальная инициализация и сброс
        pclk    = 0;
        presetn = 1'b1;

        repeat (5) @(posedge pclk);
        presetn = 1'b0; // удерживаем сброс
        repeat (5) @(posedge pclk);
        presetn = 1'b1; // отпускаем сброс
        repeat (5) @(posedge pclk);

        // INVERSE
        // Проверяем инверсию на трёх крайних значениях:
        // обычное, ноль и все единицы.
        $display("\n-- TEST 1: INVERSE --");
        MASTER.apb_write(p_device_offset + 32'h0, 32'h0000_00FF);
        MASTER.apb_write(p_device_offset + 32'h8, 32'h0000_0004); // start=1, op=00
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

        // XOR
        // Два случая: разные операнды (результат — все единицы)
        // и одинаковые (результат — ноль).
        $display("\n-- TEST 2: XOR --");
        MASTER.apb_write(p_device_offset + 32'h0, 32'hAAAA_AAAA);
        MASTER.apb_write(p_device_offset + 32'h4, 32'h5555_5555);
        MASTER.apb_write(p_device_offset + 32'h8, 32'h0000_0005); // start=1, op=01
        MASTER.apb_read (p_device_offset + 32'hC, data_from_device);
        check(data_from_device, 32'hFFFF_FFFF, "XOR AAAAAAAA^55555555");

        MASTER.apb_write(p_device_offset + 32'h0, 32'h1234_5678);
        MASTER.apb_write(p_device_offset + 32'h4, 32'h1234_5678);
        MASTER.apb_write(p_device_offset + 32'h8, 32'h0000_0005);
        MASTER.apb_read (p_device_offset + 32'hC, data_from_device);
        check(data_from_device, 32'h0000_0000, "XOR A^A");

        //CMP EQ
        // Проверяем равенство и неравенство операндов.
        $display("\n-- TEST 3: CMP EQ --");
        MASTER.apb_write(p_device_offset + 32'h0, 32'h1234_5678);
        MASTER.apb_write(p_device_offset + 32'h4, 32'h1234_5678);
        MASTER.apb_write(p_device_offset + 32'h8, 32'h0000_0006); // start=1, op=10
        MASTER.apb_read (p_device_offset + 32'hC, data_from_device);
        check(data_from_device, 32'h0000_0001, "CMP EQ (equal)");

        MASTER.apb_write(p_device_offset + 32'h0, 32'h1234_5678);
        MASTER.apb_write(p_device_offset + 32'h4, 32'h8765_4321);
        MASTER.apb_write(p_device_offset + 32'h8, 32'h0000_0006);
        MASTER.apb_read (p_device_offset + 32'hC, data_from_device);
        check(data_from_device, 32'h0000_0000, "CMP EQ (not equal)");

        // CMP GT
        // A > B: все три комбинации отношений.
        $display("\n-- TEST 4: CMP GT --");
        MASTER.apb_write(p_device_offset + 32'h0, 32'h0000_0005);
        MASTER.apb_write(p_device_offset + 32'h4, 32'h0000_0003);
        MASTER.apb_write(p_device_offset + 32'h8, 32'h0000_0007); // start=1, op=11
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

        //READBACK
        // Записываем и читаем обратно оба операнда.
        // Затем запускаем операцию, чтобы проверить автосброс start.
        $display("\n-- TEST 5: READBACK --");
        MASTER.apb_write(p_device_offset + 32'h0, 32'hDEAD_BEEF);
        MASTER.apb_write(p_device_offset + 32'h4, 32'hCAFE_F00D);
        MASTER.apb_read (p_device_offset + 32'h0, data_from_device);
        check(data_from_device, 32'hDEAD_BEEF, "RD OP1");
        MASTER.apb_read (p_device_offset + 32'h4, data_from_device);
        check(data_from_device, 32'hCAFE_F00D, "RD OP2");

        MASTER.apb_write(p_device_offset + 32'h8, 32'h0000_0004); // start=1, op=00
        MASTER.apb_read (p_device_offset + 32'h8, data_from_device);
        check(data_from_device, 32'h0000_0000, "RD CTRL (start autoclr)");

        // WRITE TO RESULT (ignored)
        // RESULT — read-only. Запись не должна менять значение.
        $display("\n-- TEST 6: WRITE TO RESULT (ignored) --");
        MASTER.apb_write(p_device_offset + 32'h0, 32'h0000_0001);
        MASTER.apb_write(p_device_offset + 32'h8, 32'h0000_0004); // INV -> 0xFFFFFFFE
        MASTER.apb_write(p_device_offset + 32'hC, 32'hDEAD_BEEF); // попытка перезаписи
        MASTER.apb_read (p_device_offset + 32'hC, data_from_device);
        check(data_from_device, 32'hFFFF_FFFE, "RESULT unchanged");

        // START AUTOCLEAR
        // После старта бит control[2] должен автоматически сброситься,
        // иначе операция повторялась бы в каждом такте.
        $display("\n-- TEST 7: START AUTOCLEAR --");
        MASTER.apb_write(p_device_offset + 32'h0, 32'h0000_0007);
        MASTER.apb_write(p_device_offset + 32'h8, 32'h0000_0004); // INV
        MASTER.apb_read (p_device_offset + 32'h8, data_from_device);
        check(data_from_device, 32'h0000_0000, "CTRL after start");

        //RESET
        // Сбрасываем устройство в середине работы и проверяем,
        // что все регистры обнулились.
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

        //Завершение симуляции
        repeat (10) @(posedge pclk);

        if (errors == 0) $display("\n=== ALL TESTS PASSED (18 checks) ===");
        else             $display("\n=== %0d ERRORS ===", errors);
        $finish;
    end

    // Страховка от зависания
    initial begin
        #500000;
        $fatal("TIMEOUT");
    end

endmodule