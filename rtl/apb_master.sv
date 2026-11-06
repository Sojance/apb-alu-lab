// Модель APB Master (инициирует передачи)
module apb_master (
    input  logic        pclk,       // Вход: синхросигнал шины
    input  logic        presetn,    // Вход: сигнал сброса
    output logic        psel,       // Выход: выбор устройства
    output logic        penable,    // Выход: фаза ACCESS
    output logic        pwrite,     // Выход: 1-запись, 0-чтение
    output logic [31:0] paddr,      // Выход: адрес
    output logic [31:0] pwdata,     // Выход: данные для записи
    input  logic        pready,     // Вход: готовность слейва
    input  logic        pslverr,    // Вход: ошибка от слейва
    input  logic [31:0] prdata      // Вход: прочитанные данные
);
    // Инициализация выходных сигналов (защита от X)
    initial begin
        psel    = 1'b0;
        penable = 1'b0;
        pwrite  = 1'b0;
        paddr   = '0;
        pwdata  = '0;
    end
    // Задача для записи данных в слейв
    task apb_write(input [31:0] addr, input [31:0] data);
        wait ((penable == 0) && (pready == 0)); // Ждем свободную шину
        @(posedge pclk);                        // Ждем такт
        psel <= 1'b1; paddr <= addr;            // Фаза SETUP
        pwdata <= data; pwrite <= 1'b1;
        @(posedge pclk);                        // Ждем такт
        penable <= 1'b1;                        // Фаза ACCESS
        @(posedge pclk);
        wait (pready == 1'b1);                  // Ждем ответа слейва
        @(posedge pclk);
        psel <= 1'b0; penable <= 1'b0; pwrite <= 1'b0; // Завершение
        @(posedge pclk);
    endtask
    // Задача для чтения данных из слейва
    task apb_read(input [31:0] addr, output logic [31:0] data);
        wait ((penable == 0) && (pready == 0)); // Ждем свободную шину
        @(posedge pclk);                        // Ждем такт
        psel <= 1'b1; pwrite <= 1'b0;           // Фаза SETUP
        paddr <= addr;
        @(posedge pclk);                        // Ждем такт
        penable <= 1'b1;                        // Фаза ACCESS
        @(posedge pclk);
        wait (pready == 1'b1);                  // Ждем ответа слейва
        @(posedge pclk);
        data <= prdata;                         // Считываем данные
        psel <= 1'b0; penable <= 1'b0;          // Завершение
        @(posedge pclk);
    endtask
endmodule
