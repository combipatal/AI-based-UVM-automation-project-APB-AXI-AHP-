
class AHB_Model:
    BYTE     = 0b000
    HALFWORD = 0b001
    WORD     = 0b010
    
    def __init__(self, mem_size=4096):
        self.mem = {}
        self.mem_size = mem_size
        
    def write(self, addr, data, size=WORD):
        if addr >= self.mem_size:
            print(f"[AHB_Model] ERROR: Address 0x{addr:08x} out of range")
            return
        
        if size == self.BYTE:
            self.mem[addr] = data & 0xFF
            print(f"[AHB_Model] Write BYTE: Addr=0x{addr:08x}, Data=0x{data & 0xFF:02x}")
        elif size == self.HALFWORD:
            aligned_addr = addr & ~0x1
            self.mem[aligned_addr] = data & 0xFFFF
            print(f"[AHB_Model] Write HALFWORD: Addr=0x{aligned_addr:08x}, Data=0x{data & 0xFFFF:04x}")
        else:
            aligned_addr = addr & ~0x3
            self.mem[aligned_addr] = data & 0xFFFFFFFF
            print(f"[AHB_Model] Write WORD: Addr=0x{aligned_addr:08x}, Data=0x{data & 0xFFFFFFFF:08x}")

    def read(self, addr, size=WORD):
        if addr >= self.mem_size:
            print(f"[AHB_Model] ERROR: Address 0x{addr:08x} out of range")
            return 0
        
        if size == self.BYTE:
            data = self.mem.get(addr, 0) & 0xFF
            print(f"[AHB_Model] Read BYTE: Addr=0x{addr:08x}, Data=0x{data:02x}")
        elif size == self.HALFWORD:
            aligned_addr = addr & ~0x1
            data = self.mem.get(aligned_addr, 0) & 0xFFFF
            print(f"[AHB_Model] Read HALFWORD: Addr=0x{aligned_addr:08x}, Data=0x{data:04x}")
        else:
            aligned_addr = addr & ~0x3
            data = self.mem.get(aligned_addr, 0) & 0xFFFFFFFF
            print(f"[AHB_Model] Read WORD: Addr=0x{aligned_addr:08x}, Data=0x{data:08x}")
        
        return data

    def reset(self):
        self.mem.clear()
        print("[AHB_Model] Memory reset")


model = AHB_Model()


def dpi_mem_write(addr, data):
    model.write(addr, data, size=AHB_Model.WORD)


def dpi_mem_read(addr):
    return model.read(addr, size=AHB_Model.WORD)


def dpi_mem_reset():
    model.reset()
