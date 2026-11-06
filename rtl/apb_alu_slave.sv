// APB Slave — вариант 7.
// Выполняет над двумя 32-битными операндами:
// побитовую инверсию (~A);
// сложение по модулю 2 (A ^ B);
// сравнение A == B (и бонусом A > B).
//
// Карта регистров:
//   0x0 — OPERAND1   (R/W)
//   0x4 — OPERAND2   (R/W)
//   0x8 — CONTROL    (R/W): [1:0] код операции, [2] старт (автосброс)
//   0xC — RESULT     (R):   результат последней операции
module apb_alu_slave (
    input  logic        pclk,
    input  logic        presetn,
    input  logic [31:0] paddr,
    input  logic [31:0] pwdata,
    input  logic        psel,
    input  logic        penable,
    input  logic        pwrite,
    output logic        pready,
    output logic        pslverr,
    output logic [31:0] prdata
);

    //Внутренние регистры устройства
    logic [31:0] operand1;
    logic [31:0] operand2;
    logic [31:0] control;
    logic [31:0] result;

    //Локальные константы адресов (декодируем младшие 4 бита)
    localparam logic [3:0] ADDR_OP1     = 4'h0;
    localparam logic [3:0] ADDR_OP2     = 4'h4;
    localparam logic [3:0] ADDR_CONTROL = 4'h8;
    localparam logic [3:0] ADDR_RESULT  = 4'hC;

    // Условия записи и чтения по протоколу APB (фаза ACCESS)
    wire apb_write = psel && penable && pwrite;
    wire apb_read  = psel && penable && !pwrite;

    // Запись в регистры и выполнение операции.
    // Операция запускается по биту control[2] (start) и сбрасывает его
    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            // Асинхронный сброс: обнуляем всё состояние
            operand1 <= '0;
            operand2 <= '0;
            control  <= '0;
            result   <= '0;
        end else if (apb_write) begin
            // Запись в регистры по адресу
            case (paddr[3:0])
                ADDR_OP1:     operand1 <= pwdata;
                ADDR_OP2:     operand2 <= pwdata;
                ADDR_CONTROL: control  <= pwdata;
                // Запись в RESULT игнорируется (регистр только для чтения)
                default: ;
            endcase
        end else if (control[2]) begin
            // Старт операции: выбираем её по полю control[1:0]
            unique case (control[1:0])
                2'b00: result <= ~operand1; // INV
                2'b01: result <= operand1 ^ operand2; // XOR
                2'b10: result <= (operand1 == operand2) ? 32'h1 : 32'h0; // A == B
                2'b11: result <= (operand1 >  operand2) ? 32'h1 : 32'h0; // A > B
            endcase
            control[2] <= 1'b0; // автосброс старта
        end
    end

    // Чтение регистров. Работает только в фазе ACCESS при pwrite=0.
    always_comb begin
        prdata = 32'h0;
        if (apb_read) begin
            case (paddr[3:0])
                ADDR_OP1:     prdata = operand1;
                ADDR_OP2:     prdata = operand2;
                ADDR_CONTROL: prdata = control;
                ADDR_RESULT:  prdata = result;
                default:      prdata = 32'h0;
            endcase
        end
    end

    // APB handshake.
    // pready поднимаем только в фазе ACCESS
    // ожидания мастера (wait (penable==0 && pready==0) в SETUP).
    assign pready  = psel && penable;
    assign pslverr = 1'b0;

endmodule