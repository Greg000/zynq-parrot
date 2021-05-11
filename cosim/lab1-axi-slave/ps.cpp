//
// this is an example of "host code" that can either run in cosim or on the PS
// we can use the same C host code and
// the API we provide abstracts away the
// communication plumbing differences.


#include <stdlib.h>
#include <stdio.h>
#include "bp_zynq_pl.h"

int main(int argc, char **argv) {
        bp_zynq_pl *zpl = new bp_zynq_pl(argc, argv);

	// this program just communicates with a "loopback accelerator"
	// that has 4 control registers that you can read and write
	assert( (zpl->axil_read(0x0 + ADDR_BASE) == (0x8)));
	assert( (zpl->axil_read(0x8 + ADDR_BASE) == (0x0)));
	
	int val1 = 0xDEADBEEF;
	int val2 = 0xCAFEBABE;
	int mask1 = 0xf;
	int mask2 = 0xf;
	int factors = 0x0;
	
	// Set the amp/dec factor to be 0
	zpl->axil_write(0x10 + ADDR_BASE, factors, mask1);
	// Write one thing to PL
	zpl->axil_write(0x4 + ADDR_BASE, val1, mask2);
	// Should get back val1
	assert( (zpl->axil_read(0xC + ADDR_BASE) == val1));
	
	// Set amp = 8, dec = 0
	factors = 0x8;
	zpl->axil_write(0x10 + ADDR_BASE, factors, mask1);
	zpl->axil_write(0x4 + ADDR_BASE, val2, mask2);
	
	// This is not part of the spec
	// addr 20 and 24 can be read to confirm the amplification/decimation factor
	assert( (zpl->axil_read(20 + ADDR_BASE) == 0x8));
	assert( (zpl->axil_read(24 + ADDR_BASE) == 0x0));
	
	// Read addr 8, should get 8
	assert( (zpl->axil_read(0x8 + ADDR_BASE) == 0x8));
	// Read addr 0, should get 7
	assert( (zpl->axil_read(0x0 + ADDR_BASE) == 0x7));
	
	// Read from PL 9 times. Should all get val2
	for (int i = 0; i < 9; i++) {
	    assert( (zpl->axil_read(0xC + ADDR_BASE) == val2));
	}
	
	// Read one more time, should get -1
	assert( (zpl->axil_read(0xC + ADDR_BASE) == 0xffffffff));
	
	// Check both fifos are empty
	// Read addr 8, should get 8
	assert( (zpl->axil_read(0x8 + ADDR_BASE) == 0x0));
	// Read addr 0, should get 7
	assert( (zpl->axil_read(0x0 + ADDR_BASE) == 0x8));
	
	zpl->done();

	delete zpl;
	exit(EXIT_SUCCESS);
}

