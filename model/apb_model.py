
class APB_Model:
    def __init__(self):
        self.mem = {}

    def write(self, addr, data):
        """
        Write data to the specified address.
        Address is word-aligned (checking logic can be added here).
        """
        # Align address to 32-bit word boundary equivalent if needed, 
        # but here we assume the testbench passes aligned addresses or we treat strictly.
        # Simple Key-Value storage
        self.mem[addr] = data
        print(f"[APB_Model] Write: Addr=0x{addr:08x}, Data=0x{data:08x}")

    def read(self, addr):
        """
        Read data from the specified address.
        Returns 0 if address is uninitialized (like the RTL default).
        """
        data = self.mem.get(addr, 0)
        print(f"[APB_Model] Read : Addr=0x{addr:08x}, Data=0x{data:08x}")
        return data

# Global instance for DPI-C to interact with
model = APB_Model()

# DPI-C specific wrapper functions (to be called from C/SV)
def dpi_mem_write(addr, data):
    model.write(addr, data)

def dpi_mem_read(addr):
    return model.read(addr)
