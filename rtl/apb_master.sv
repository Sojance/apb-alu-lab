// APB Master — модель инициатора передач на шине APB.
// Используется в тестбенче для формирования транзакций записи/чтения.
// Перенесён из ЛР1 без изменений.
module apb_master (
    input  logic        pclk, // тактовый сигнал шины
    input  logic        presetn, // асинхронный сброс, активный низким уровнем
    output logic        psel, // выбор устройства (slave)
    output logic        penable, // фаза ACCESS (передача активна)
    output logic        pwrite, // 1 — запись, 0 — чтение
    output logic [31:0] paddr,  // адрес
    output logic [31:0] pwdata, // данные для записи
    input  logic        pready, // готовность слейва
    input  logic        pslverr, // признак ошибки от слейва
    input  logic [31:0] prdata  // прочитанные данные
);

    // Инициализация выходов, чтобы не было X в начале симуляции
    initial begin
        psel    = 1'b0;
        penable = 1'b0;
        pwrite  = 1'b0;
        paddr   = '0;
        pwdata  = '0;
    end

    // Задача записи по протоколу APB:
    //1. ждём, пока шина свободна;
    //2. фаза SETUP — выставляем psel, paddr, pwdata, pwrite;
    //3. фаза ACCESS — поднимаем penable и ждём pready=1 от слейва;
    //4. снимаем сигналы, транзакция завершена.
    task apb_write(input [31:0] addr, input [31:0] data);
        wait ((penable == 0) && (pready == 0)); // ждём свободную шину
        @(posedge pclk);

        //SETUP
        psel   <= 1'b1;
        paddr  <= addr;
        pwdata <= data;
        pwrite <= 1'b1;

        @(posedge pclk);

        //ACCESS
        penable <= 1'b1;
        @(posedge pclk);
        wait (pready == 1'b1); // ждём ответа слейва
        @(posedge pclk);

        //завершение
        psel    <= 1'b0;
        penable <= 1'b0;
        pwrite  <= 1'b0;
        @(posedge pclk);
    endtask

    // Задача чтения. Отличается от записи тем, что pwrite=0,
    // а данные забираются из prdata в момент завершения транзакции.
    task apb_read(input [31:0] addr, output logic [31:0] data);
        wait ((penable == 0) && (pready == 0));
        @(posedge pclk);

        //SETUP
        psel   <= 1'b1;
        pwrite <= 1'b0;
        paddr  <= addr;

        @(posedge pclk);

        //ACCESS
        penable <= 1'b1;
        @(posedge pclk);
        wait (pready == 1'b1);

        @(posedge pclk);
        data <= prdata; // забираем прочитанные данные
        psel    <= 1'b0;
        penable <= 1'b0;
        @(posedge pclk);
    endtask

endmodule