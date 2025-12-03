// ===================================================================
// Sistem Kontrol Lingkungan Otomatis - Verilog HDL untuk FPGA
// Mochamad Rafly Firmansyah / 2042241130
// ===================================================================

module environmental_control_fsm (
    input wire clk,           // Clock signal
    input wire reset,         // Reset signal (active high)
    input wire S1,            // Temperature sensor (1=normal, 0=abnormal)
    input wire S2,            // Humidity sensor
    input wire S3,            // VOC sensor
    input wire S4,            // Dust sensor
    input wire S5,            // Airflow sensor
    input wire S6,            // Light sensor
    output reg A1,            // Exhaust Fan
    output reg A2,            // Inline Duct Fan (always 0)
    output reg A3,            // Humidifier
    output reg A4,            // Dehumidifier
    output reg A5,            // Cooling System
    output reg A6,            // LED Light System
    output reg [2:0] current_state  // Current FSM state (for monitoring)
);

    // State encoding
    localparam S0_IDLE = 3'b000;      // All sensors normal
    localparam S1_SINGLE = 3'b001;    // 1 sensor abnormal
    localparam S2_MULTIPLE = 3'b010;  // 2-3 sensors abnormal
    localparam S3_CRITICAL = 3'b011;  // 4-5 sensors abnormal
    localparam S4_EMERGENCY = 3'b100; // All sensors abnormal

    // Internal registers
    reg [2:0] next_state;
    reg [2:0] abnormal_count;

    // Count abnormal sensors
    always @(*) begin
        abnormal_count = 3'b000;
        if (!S1) abnormal_count = abnormal_count + 1;
        if (!S2) abnormal_count = abnormal_count + 1;
        if (!S3) abnormal_count = abnormal_count + 1;
        if (!S4) abnormal_count = abnormal_count + 1;
        if (!S5) abnormal_count = abnormal_count + 1;
        if (!S6) abnormal_count = abnormal_count + 1;
    end

    // Next State Logic
    always @(*) begin
        case (abnormal_count)
            3'd0: next_state = S0_IDLE;
            3'd1: next_state = S1_SINGLE;
            3'd2, 3'd3: next_state = S2_MULTIPLE;
            3'd4, 3'd5: next_state = S3_CRITICAL;
            3'd6: next_state = S4_EMERGENCY;
            default: next_state = S0_IDLE;
        endcase
    end

    // State Register (D Flip-Flops)
    always @(posedge clk or posedge reset) begin
        if (reset)
            current_state <= S0_IDLE;
        else
            current_state <= next_state;
    end

    // Output Logic (Moore Machine)
    always @(*) begin
        // Default: all actuators OFF
        A1 = 0; A2 = 0; A3 = 0; A4 = 0; A5 = 0; A6 = 0;
        
        case (current_state)
            S0_IDLE: begin
                // All OFF (already set)
            end
            
            S1_SINGLE: begin
                // Activate specific actuator based on which sensor is abnormal
                if (!S1) A5 = 1;      // Temperature -> Cooling
                if (!S2) A3 = 1;      // Humidity -> Dehumidifier
                if (!S3) A1 = 1;      // VOC -> Exhaust Fan
                if (!S4) A1 = 1;      // Dust -> Exhaust Fan
                if (!S5) A4 = 1;      // Airflow -> Inline Duct Fan
                if (!S6) A6 = 1;      // Light -> LED System
            end
            
            S2_MULTIPLE: begin
                // Multiple actuators active
                if (!S1) A5 = 1;
                if (!S2) A3 = 1;
                if (!S3) A1 = 1;
                if (!S4) A1 = 1;
                if (!S5) A4 = 1;
                if (!S6) A6 = 1;
            end
            
            S3_CRITICAL: begin
                // Most protection actuators active
                if (!S1) A5 = 1;
                if (!S2) A3 = 1;
                if (!S3) A1 = 1;
                if (!S4) A1 = 1;
                if (!S5) A4 = 1;
                if (!S6) A6 = 1;
            end
            
            S4_EMERGENCY: begin
                // All protection actuators ON
                A1 = 1;  // Exhaust Fan
                A3 = 1;  // Dehumidifier
                A4 = 1;  // Inline Duct Fan
                A5 = 1;  // Cooling System
                A6 = 1;  // LED System
                A2 = 0;  // Always OFF
            end
            
            default: begin
                A1 = 0; A2 = 0; A3 = 0; A4 = 0; A5 = 0; A6 = 0;
            end
        endcase
    end

endmodule

// ===================================================================
// TESTBENCH untuk Simulasi
// ===================================================================

module tb_environmental_control;
    reg clk;
    reg reset;
    reg S1, S2, S3, S4, S5, S6;
    wire A1, A2, A3, A4, A5, A6;
    wire [2:0] current_state;

    // Instantiate the module
    environmental_control_fsm uut (
        .clk(clk),
        .reset(reset),
        .S1(S1), .S2(S2), .S3(S3), .S4(S4), .S5(S5), .S6(S6),
        .A1(A1), .A2(A2), .A3(A3), .A4(A4), .A5(A5), .A6(A6),
        .current_state(current_state)
    );

    // Clock generation (50 MHz = 20ns period)
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    // Test scenarios
    initial begin
        // Initialize waveform dump
        $dumpfile("environmental_control.vcd");
        $dumpvars(0, tb_environmental_control);
        
        // Display header
        $display("Time\tState\tS1 S2 S3 S4 S5 S6\tA1 A2 A3 A4 A5 A6");
        $display("------------------------------------------------------------");
        
        // Test Case 1: Reset
        reset = 1; S1=1; S2=1; S3=1; S4=1; S5=1; S6=1;
        #20 reset = 0;
        #20 $display("%0t\tS0\t%b  %b  %b  %b  %b  %b\t%b  %b  %b  %b  %b  %b", 
                     $time, S1,S2,S3,S4,S5,S6, A1,A2,A3,A4,A5,A6);
        
        // Test Case 2: Single sensor abnormal (Temperature)
        S1=0; S2=1; S3=1; S4=1; S5=1; S6=1;
        #40 $display("%0t\tS1\t%b  %b  %b  %b  %b  %b\t%b  %b  %b  %b  %b  %b", 
                     $time, S1,S2,S3,S4,S5,S6, A1,A2,A3,A4,A5,A6);
        
        // Test Case 3: Multiple sensors abnormal (Temp + Humidity)
        S1=0; S2=0; S3=1; S4=1; S5=1; S6=1;
        #40 $display("%0t\tS2\t%b  %b  %b  %b  %b  %b\t%b  %b  %b  %b  %b  %b", 
                     $time, S1,S2,S3,S4,S5,S6, A1,A2,A3,A4,A5,A6);
        
        // Test Case 4: Critical condition (4 sensors abnormal)
        S1=0; S2=0; S3=0; S4=0; S5=1; S6=1;
        #40 $display("%0t\tS3\t%b  %b  %b  %b  %b  %b\t%b  %b  %b  %b  %b  %b", 
                     $time, S1,S2,S3,S4,S5,S6, A1,A2,A3,A4,A5,A6);
        
        // Test Case 5: Emergency (All sensors abnormal)
        S1=0; S2=0; S3=0; S4=0; S5=0; S6=0;
        #40 $display("%0t\tS4\t%b  %b  %b  %b  %b  %b\t%b  %b  %b  %b  %b  %b", 
                     $time, S1,S2,S3,S4,S5,S6, A1,A2,A3,A4,A5,A6);
        
        // Test Case 6: Recovery to normal
        S1=1; S2=1; S3=1; S4=1; S5=1; S6=1;
        #40 $display("%0t\tS0\t%b  %b  %b  %b  %b  %b\t%b  %b  %b  %b  %b  %b", 
                     $time, S1,S2,S3,S4,S5,S6, A1,A2,A3,A4,A5,A6);
        
        #100 $finish;
    end

endmodule