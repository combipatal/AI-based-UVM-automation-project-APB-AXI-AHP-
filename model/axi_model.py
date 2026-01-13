
class AXI_Model:
    def __init__(self):
        self.mem = {}

    def write(self, addr, data):
        """
        Write data to the specified address.
        AXI is byte-addressable, but here we treat it as word-aligned for simplicity in this model.
        """
        # Align address to 32-bit word boundary (mask lower 2 bits)
        aligned_addr = addr & ~0x3
        self.mem[aligned_addr] = data
        print(f"[AXI_Model] Write: Addr=0x{addr:08x} (Aligned: 0x{aligned_addr:08x}), Data=0x{data:08x}")

    def read(self, addr):
        """
        Read data from the specified address.
        Returns 0 if address is uninitialized.
        """
        aligned_addr = addr & ~0x3
        data = self.mem.get(aligned_addr, 0)
        print(f"[AXI_Model] Read : Addr=0x{addr:08x} (Aligned: 0x{aligned_addr:08x}), Data=0x{data:08x}")
        return data

# Global instance for DPI-C to interact with
model = AXI_Model()

# DPI-C specific wrapper functions (to be called from C/SV)
# These function names MUST match what is called in wrapper.c (which is dynamic now)
# But wait, wrapper.c calls `dpi_mem_write` / `dpi_mem_read`.
# Those are C functions calling Python functions via `PyObject_GetAttrString`.
# So this Python file MUST have `dpi_mem_write` and `dpi_mem_read` functions defined at module level.

def dpi_mem_write(addr, data):
    model.write(addr, data)

def dpi_mem_read(addr):
    return model.read(addr)
