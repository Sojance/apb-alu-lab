// APB Slave — Вариант 7:
// Инверсия, XOR, сравнение двух 32-битных чисел.
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

    logic [31:0] operand1;
    logic [31:0] operand2;
    logic [31:0] control;
    logic [31:0] result;

    localparam logic [3:0] ADDR_OP1     = 4'h0;
    localparam logic [3:0] ADDR_OP2     = 4'h4;
    localparam logic [3:0] ADDR_CONTROL = 4'h8;
    localparam logic [3:0] ADDR_RESULT  = 4'hC;

    wire apb_write = psel && penable && pwrite;
    wire apb_read  = psel && penable && !pwrite;

    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            operand1 <= '0;
            operand2 <= '0;
            control  <= '0;
            result   <= '0;
        end else if (apb_write) begin
            case (paddr[3:0])
                ADDR_OP1:     operand1 <= pwdata;
                ADDR_OP2:     operand2 <= pwdata;
                ADDR_CONTROL: control  <= pwdata;
                default: ; 
            endcase
        end else if (control[2]) begin 
            unique case (control[1:0])
                2'b00: result <= ~operand1;                              
                2'b01: result <= operand1 ^ operand2;                    
                2'b10: result <= (operand1 == operand2) ? 32'h1 : 32'h0; 
                2'b11: result <= (operand1 >  operand2) ? 32'h1 : 32'h0; 
            endcase
            control[2] <= 1'b0; 
        end
    end

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

    // pready = 1 только в фазе ACCESS — совместимо с мастером из ЛР1
    assign pready  = psel && penable;
    assign pslverr = 1'b0;

endmodule