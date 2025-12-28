
/*
FOUR HOT STATE MACHINE
*/



module inertial_integrator(
    input  logic              clk,
    input  logic              rst_n,
    input  logic              vld,          // new sensor sample valid
    input  logic [15:0]       ptch_rt,      // raw pitch rate from gyro
    input  logic [15:0]       AZ,           // raw accel Z from sensor
    output logic signed [15:0] ptch         // fused pitch estimate
);

    // 27-bit internal integrator state for pitch
    logic signed [26:0] ptch_int;

    // Offset-compensated pitch rate and AZ (both signed)
    logic signed [15:0] ptch_rt_comp;
    logic signed [15:0] AZ_comp;

    // Sensor offsets from lab spec
    localparam logic signed [15:0] AZ_OFFSET      = 16'sh00A0;
    localparam logic signed [15:0] PTCH_RT_OFFSET = 16'sh0050;

    // Remove DC offsets from raw sensor readings
    assign ptch_rt_comp = $signed(ptch_rt) - PTCH_RT_OFFSET;
    assign AZ_comp      = $signed(AZ)      - AZ_OFFSET;

    // ------------------------------------------------------------------
    // Convert AZ into an approximate pitch angle (ptch_acc)
    // ptch_acc_product = AZ_comp * scale_factor
    // scale factor 327 chosen from lab notes to map AZ range into
    // a pitch range that matches ptch_int scaling.
    // ------------------------------------------------------------------
    logic signed [25:0] ptch_acc_product;   // intermediate product
    logic signed [15:0] ptch_acc;           // accel-based pitch estimate

  assign ptch_acc_product = (AZ_comp <<< 8) + (AZ_comp <<< 6) + (AZ_comp <<< 3); 


    //assign ptch_acc_product = AZ_comp * 16'sd327;
    // Take upper bits of product and sign-extend to 16 bits
    assign ptch_acc = {{3{ptch_acc_product[25]}}, ptch_acc_product[25:13]};

    // ------------------------------------------------------------------
    // Fusion offset: drive ptch toward ptch_acc in small steps (±1024)
    // If ptch_acc > ptch  → add +1024 each valid sample
    // If ptch_acc < ptch  → add -1024 each valid sample
    // This gently pulls the integral toward the accelerometer estimate.
    // ------------------------------------------------------------------
    logic signed [11:0] fusion_ptch_offset;

    assign fusion_ptch_offset =
        (ptch_acc > ptch) ? 12'sd1024 : -12'sd1024;

    // ------------------------------------------------------------------
    // Main integrator
    // - Integrate the NEGATIVE of pitch rate (ptch_rt_comp)
    // - Add fusion_ptch_offset to blend with accelerometer estimate
    // Update only when vld is asserted.
    // ------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            ptch_int <= 27'sd0;
        else if (vld)
            ptch_int <= ptch_int
                        - {{11{ptch_rt_comp[15]}}, ptch_rt_comp}  // -ptch_rt_comp
                        + $signed({{15{fusion_ptch_offset[11]}}, fusion_ptch_offset});                     // fusion nudge
        // else: hold ptch_int
    end

    // Output pitch is the upper 16 bits of ptch_int
    assign ptch = ptch_int[26:11];

endmodule




