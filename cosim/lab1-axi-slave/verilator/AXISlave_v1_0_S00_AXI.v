
`timescale 1 ns / 1 ps
    `include "bsg_defines.v"
	module AXISlave_v1_0_S00_AXI #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line

		// Width of S_AXI data bus
		parameter integer C_S_AXI_DATA_WIDTH	= 32,
		// Width of S_AXI address bus
		parameter integer C_S_AXI_ADDR_WIDTH	= 32,
		// size of the ps->pl fifo
		parameter integer size_ps2pl            = 8,
		// size of the pl->ps fifo
		parameter integer size_pl2ps            = 8
	)
	(
		// Users to add ports here

		// User ports ends
		// Do not modify the ports beyond this line

		// Global Clock Signal
		input wire  S_AXI_ACLK,
		// Global Reset Signal. This Signal is Active LOW
		input wire  S_AXI_ARESETN,
		// Write address (issued by master, acceped by Slave)
		input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
		// Write channel Protection type. This signal indicates the
    		// privilege and security level of the transaction, and whether
    		// the transaction is a data access or an instruction access.
		input wire [2 : 0] S_AXI_AWPROT,
		// Write address valid. This signal indicates that the master signaling
    		// valid write address and control information.
		input wire  S_AXI_AWVALID,
		// Write address ready. This signal indicates that the slave is ready
    		// to accept an address and associated control signals.
		output wire  S_AXI_AWREADY,
		// Write data (issued by master, acceped by Slave) 
		input wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_WDATA,
		// Write strobes. This signal indicates which byte lanes hold
    		// valid data. There is one write strobe bit for each eight
    		// bits of the write data bus.    
		input wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
		// Write valid. This signal indicates that valid write
    		// data and strobes are available.
		input wire  S_AXI_WVALID,
		// Write ready. This signal indicates that the slave
    		// can accept the write data.
		output wire  S_AXI_WREADY,
		// Write response. This signal indicates the status
    		// of the write transaction.
		output wire [1 : 0] S_AXI_BRESP,
		// Write response valid. This signal indicates that the channel
    		// is signaling a valid write response.
		output wire  S_AXI_BVALID,
		// Response ready. This signal indicates that the master
    		// can accept a write response.
		input wire  S_AXI_BREADY,
		// Read address (issued by master, acceped by Slave)
		input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
		// Protection type. This signal indicates the privilege
    		// and security level of the transaction, and whether the
    		// transaction is a data access or an instruction access.
		input wire [2 : 0] S_AXI_ARPROT,
		// Read address valid. This signal indicates that the channel
    		// is signaling valid read address and control information.
		input wire  S_AXI_ARVALID,
		// Read address ready. This signal indicates that the slave is
    		// ready to accept an address and associated control signals.
		output wire  S_AXI_ARREADY,
		// Read data (issued by slave)
		output wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_RDATA,
		// Read response. This signal indicates the status of the
    		// read transfer.
		output wire [1 : 0] S_AXI_RRESP,
		// Read valid. This signal indicates that the channel is
    		// signaling the required read data.
		output wire  S_AXI_RVALID,
		// Read ready. This signal indicates that the master can
    		// accept the read data and response information.
		input wire  S_AXI_RREADY
	);

	// AXI4LITE signals
	reg [C_S_AXI_ADDR_WIDTH-1 : 0] 	axi_awaddr;
	reg  	axi_awready;
	reg  	axi_wready;
	reg [1 : 0] 	axi_bresp;
	reg  	axi_bvalid;
	reg [C_S_AXI_ADDR_WIDTH-1 : 0] 	axi_araddr;
	reg  	axi_arready;
	reg [C_S_AXI_DATA_WIDTH-1 : 0] 	axi_rdata;
	reg [1 : 0] 	axi_rresp;
	reg  	axi_rvalid;

	// Example-specific design signals
	// local parameter for addressing 32 bit / 64 bit C_S_AXI_DATA_WIDTH
	// ADDR_LSB is used for addressing 32/64 bit registers/memories
	// ADDR_LSB = 2 for 32 bits (n downto 2)
	// ADDR_LSB = 3 for 64 bits (n downto 3)
	localparam integer ADDR_LSB = (C_S_AXI_DATA_WIDTH/32) + 1;
	localparam integer OPT_MEM_ADDR_BITS = 1;
	
	//----------------------------------------------
	//-- Signals for user logic register space example
	//------------------------------------------------
	//-- Number of Slave Registers 4
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg0;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg1;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg2;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg3;
	wire	 slv_reg_rden;
	wire	 slv_reg_wren;
	reg [C_S_AXI_DATA_WIDTH-1:0]	 reg_data_out;
	integer	 byte_index;
	reg	 aw_en;
	
	// fifo registers
	reg [C_S_AXI_DATA_WIDTH-1:0]	data_ps2pl_in;
	wire [C_S_AXI_DATA_WIDTH-1:0]	data_ps2pl_out;
    logic                           ready_ps2pl_o;
    wire                            valid_into_ps2pl;
    wire                            valid_from_ps2pl;
    logic                           deque_ps2pl;
    
    // fifo registers
	reg [C_S_AXI_DATA_WIDTH-1:0]	data_pl2ps_in;
	wire [C_S_AXI_DATA_WIDTH-1:0]	data_pl2ps_out;
    logic                           ready_pl2ps_o;
    wire                            valid_into_pl2ps;
    wire                            valid_from_pl2ps;
    logic                           deque_pl2ps;
    
    // control registers (for amplification/decimation
    reg [7:0]                       amp_amount;
    reg [7:0]                       amp_current;
    reg [7:0]                       dec_amount;
    reg [7:0]                       dec_current;
    
    wire [`BSG_WIDTH(8)-1:0]   count_pl2ps;
    wire [`BSG_WIDTH(8)-1:0]   free_count_ps2pl;

	// I/O Connections assignments
	assign S_AXI_AWREADY	= axi_awready;
	assign S_AXI_WREADY	= axi_wready;
	assign S_AXI_BRESP	= axi_bresp;
	assign S_AXI_BVALID	= axi_bvalid;
	assign S_AXI_ARREADY	= axi_arready;
	assign S_AXI_RDATA	= axi_rdata;
	assign S_AXI_RRESP	= axi_rresp;
	assign S_AXI_RVALID	= axi_rvalid;
	
    bsg_fifo_1r1w_small # (
	   .width_p(C_S_AXI_DATA_WIDTH),
	   .els_p(8),
	   .harden_p(0),
	   .ready_THEN_valid_p(0)
	) fifo_ps2pl (
	   .clk_i(S_AXI_ACLK),
	   .reset_i(~S_AXI_ARESETN),
	   .v_i(valid_into_ps2pl),
	   .ready_o(ready_ps2pl_o),
	   .data_i(S_AXI_WDATA),
	   .v_o(valid_from_ps2pl),
	   .data_o(data_ps2pl_out),
	   .yumi_i(deque_ps2pl) // TODO: figure out when to deque
	);
	
	bsg_fifo_1r1w_small # (
	   .width_p(C_S_AXI_DATA_WIDTH),
	   .els_p(8),
	   .harden_p(0),
	   .ready_THEN_valid_p(0)
	) fifo_pl2ps (
	   .clk_i(S_AXI_ACLK),
	   .reset_i(~S_AXI_ARESETN),
	   .v_i(valid_into_pl2ps),
	   .ready_o(ready_pl2ps_o),
	   .data_i(data_ps2pl_out),
	   .v_o(valid_from_pl2ps),
	   .data_o(data_pl2ps_out),
	   .yumi_i(deque_pl2ps) // TODO: figure out when to deque
	);
	
	bsg_flow_counter # (
	   .els_p(8),
	   .count_free_p(0),
	   .ready_THEN_valid_p(0)
	) fifo_counter_ps2pl (
	   .clk_i(S_AXI_ACLK),
	   .reset_i(~S_AXI_ARESETN),
	   .v_i(valid_into_pl2ps),
	   .ready_i(ready_pl2ps_o),
	   .yumi_i(deque_pl2ps),
	   .count_o(count_pl2ps)
	);
	
	bsg_flow_counter # (
	   .els_p(8),
	   .count_free_p(1),
	   .ready_THEN_valid_p(0)
	) fifo_counter_pl2ps (
	   .clk_i(S_AXI_ACLK),
	   .reset_i(~S_AXI_ARESETN),
	   .v_i(valid_into_ps2pl),
	   .ready_i(ready_ps2pl_o),
	   .yumi_i(deque_ps2pl),
	   .count_o(free_count_ps2pl)
	);
	
	// Implement the amplification/decimation factor logic.
	// Amp_amount/dec_amount are the number of things that we need to eventually replicate/throw out,
	// and amp_current/dec_current are number of things things we have replicated/thrown out already.
	always @ (posedge S_AXI_ACLK)
	begin
	  if ( S_AXI_ARESETN == 1'b0)
	    begin
	      amp_amount <= 8;
	      amp_current <= 0;
	      dec_amount <= 3;
	      dec_current <= 0;
	    end
	  else
	    if (valid_from_ps2pl)
	      begin
	       if (amp_current == amp_amount || dec_current == dec_amount)
              begin
                // can only deque from ps2pl when ps2pl is valid
                if (ready_pl2ps_o)
                  begin
                    amp_current <= amp_current == amp_amount ? 0 : amp_current + 1;
                    dec_current <= dec_current == dec_amount ? 0 : dec_current + 1;
                  end  
              end
            else
              begin
                amp_current <= amp_current + 1;
                dec_current <= dec_current + 1;
              end
	      end
	    else if (slv_reg_wren && axi_awaddr[4:0] == 5'd16)
	       begin
	           amp_amount <= S_AXI_WDATA[7:0];
	           dec_amount <= S_AXI_WDATA[23:16];
	       end
	end


	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_awready <= 1'b0;
	      aw_en <= 1'b1;
	    end 
	  else
	    begin    
	      if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en)
	        begin
	          // slave is ready to accept write address when 
	          // there is a valid write address and write data
	          // on the write address and data bus. This design 
	          // expects no outstanding transactions. 
	          axi_awready <= 1'b1;
	          aw_en <= 1'b0;
	        end
	        else if (S_AXI_BREADY && axi_bvalid)
	            begin
	              aw_en <= 1'b1;
	              axi_awready <= 1'b0;
	            end
	      else           
	        begin
	          axi_awready <= 1'b0;
	        end
	    end 
	end       

	// Implement axi_awaddr latching
	// This process is used to latch the address when both 
	// S_AXI_AWVALID and S_AXI_WVALID are valid. 

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_awaddr <= 0;
	    end 
	  else
	    begin    
	      if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en)
	        begin
	          // Write Address latching 
	          axi_awaddr <= S_AXI_AWADDR;
	        end
	    end 
	end       

	// Implement axi_wready generation
	// axi_wready is asserted for one S_AXI_ACLK clock cycle when both
	// S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_wready is 
	// de-asserted when reset is low. 

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_wready <= 1'b0;
	    end 
	  else
	    begin    
	      if (~axi_wready && S_AXI_WVALID && S_AXI_AWVALID && aw_en )
	        begin
	          // slave is ready to accept write data when 
	          // there is a valid write address and write data
	          // on the write address and data bus. This design 
	          // expects no outstanding transactions. 
	          axi_wready <= 1'b1;
	        end
	      else
	        begin
	          axi_wready <= 1'b0;
	        end
	    end 
	end       

	// Implement memory mapped register select and write logic generation
	// The write data is accepted and written to memory mapped registers when
	// axi_awready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted. Write strobes are used to
	// select byte enables of slave registers while writing.
	// These registers are cleared when reset (active low) is applied.
	// Slave register write enable is asserted when valid address and data are available
	// and the slave is ready to accept the write address and write data.
	assign slv_reg_wren = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID;
    assign valid_into_ps2pl = slv_reg_wren && (axi_awaddr[4:0] == 3'd4);
    
	// Implement write response logic generation
	// The write response and response valid signals are asserted by the slave 
	// when axi_wready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted.  
	// This marks the acceptance of address and indicates the status of 
	// write transaction.

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_bvalid  <= 0;
	      axi_bresp   <= 2'b0;
	    end 
	  else
	    begin    
	      if (axi_awready && S_AXI_AWVALID && ~axi_bvalid && axi_wready && S_AXI_WVALID)
	        begin
	          // indicates a valid write response is available
	          axi_bvalid <= 1'b1;
	          axi_bresp  <= 2'b0; // 'OKAY' response 
	        end                   // work error responses in future
	      else
	        begin
	          if (S_AXI_BREADY && axi_bvalid) 
	            //check if bready is asserted while bvalid is high) 
	            //(there is a possibility that bready is always asserted high)   
	            begin
	              axi_bvalid <= 1'b0; 
	            end  
	        end
	    end
	end   

	// Implement axi_arready generation
	// axi_arready is asserted for one S_AXI_ACLK clock cycle when
	// S_AXI_ARVALID is asserted. axi_awready is 
	// de-asserted when reset (active low) is asserted. 
	// The read address is also latched when S_AXI_ARVALID is 
	// asserted. axi_araddr is reset to zero on reset assertion.

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_arready <= 1'b0;
	      axi_araddr  <= 32'b0;
	    end 
	  else
	    begin    
	      if (~axi_arready && S_AXI_ARVALID)
	        begin
	          // indicates that the slave has acceped the valid read address
	          axi_arready <= 1'b1;
	          // Read address latching
	          axi_araddr  <= S_AXI_ARADDR;
	        end
	      else
	        begin
	          axi_arready <= 1'b0;
	        end
	    end 
	end       

	// Implement axi_arvalid generation
	// axi_rvalid is asserted for one S_AXI_ACLK clock cycle when both 
	// S_AXI_ARVALID and axi_arready are asserted. The slave registers 
	// data are available on the axi_rdata bus at this instance. The 
	// assertion of axi_rvalid marks the validity of read data on the 
	// bus and axi_rresp indicates the status of read transaction.axi_rvalid 
	// is deasserted on reset (active low). axi_rresp and axi_rdata are 
	// cleared to zero on reset (active low).  
	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_rvalid <= 0;
	      axi_rresp  <= 0;
	    end 
	  else
	    begin    
	      if (axi_arready && S_AXI_ARVALID && ~axi_rvalid)
	        begin
	          // Valid read data is available at the read data bus
	          axi_rvalid <= 1'b1;
	          axi_rresp  <= 2'b0; // 'OKAY' response
	        end   
	      else if (axi_rvalid && S_AXI_RREADY)
	        begin
	          // Read data is accepted by the master
	          axi_rvalid <= 1'b0;
	        end                
	    end
	end    
	
    assign deque_pl2ps = axi_rvalid && S_AXI_RREADY && valid_from_pl2ps && axi_araddr[4:0] == 4'd12;
    assign deque_ps2pl = valid_from_ps2pl && (amp_current == amp_amount) && (dec_current != dec_amount || ready_pl2ps_o);
    assign valid_into_pl2ps = valid_from_ps2pl && (dec_current == dec_amount);
	// Implement memory mapped register select and read logic generation
	// Slave register read enable is asserted when valid address is available
	// and the slave is ready to accept the read address.
	assign slv_reg_rden = axi_arready & S_AXI_ARVALID & ~axi_rvalid;
	always @(*)
	begin
	  case (axi_araddr[4:0])
	    4'd0   :   reg_data_out = free_count_ps2pl;
	    4'd8   :   reg_data_out = count_pl2ps;
	    4'd12  :   reg_data_out = valid_from_pl2ps ? data_pl2ps_out : -1;
	    5'd20  :   reg_data_out = amp_amount; // NOT REQUIRED BY THES SPEC: JUST FOR TESTING
	    5'd24  :   reg_data_out = dec_amount; // NOT REQUIRED BY THES SPEC: JUST FOR TESTING
	    default :  reg_data_out = 0; 
	  endcase  
	end

	// Output register or memory read data
	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_rdata  <= 0;
	    end 
	  else
        begin    
          // When there is a valid read address (S_AXI_ARVALID) with 
          // acceptance of read address by the slave (axi_arready), 
          // output the read dada 
          if (slv_reg_rden)
            begin
              axi_rdata <= reg_data_out;     // register read data
            end   
        end
	end    

	// Add user logic here

	// User logic ends

	endmodule
