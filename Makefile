BINDIR = ~/test/mips/bin
AS = $(BINDIR)/as-mips32
OBJDUMP = $(BINDIR)/objdump

VHD_OBJ = components.o \
	  alu.o \
	  reg.o \
	  instr_mem.o \
	  if.o \
	  id.o \
	  ex.o \
	  mem.o \
	  data_mem.o \
	  atb_mips.o

# TB = tb_mips
TB = tb_mips_dmem
IMPL = impl1
IEEE = synopsys
SIMDUR = 200us

all: $(VHD_OBJ)
	ghdl -e --ieee=$(IEEE) $(TB) $(IMPL)

%.o: %.vhd
	ghdl -a --ieee=$(IEEE) $<

ex:
	./$(TB)-$(IMPL) --wave=$(TB)-$(IMPL).ghw --stop-time=$(SIMDUR)

clean:
	rm -f *.cf tb_* *.ghw *.vcd *.o
