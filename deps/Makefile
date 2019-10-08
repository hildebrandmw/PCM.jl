# Inputs: 	JULIA_HOME
# 			CXXWRAP_HOME

# Objects taken from the Makefile in pcm/pcm.so/
OBJS=$(addprefix build/,msr.o cpucounters.o pci.o mmio.o client_bw.o utils.o pcm-core.o pcm-julia.o)
DIRECTORIES = build

OPT= -g -O3
CXXFLAGS+= -Wall -fPIC $(OPT) -std=c++14 -DPCM_SILENT -DJULIA_ENABLE_THREADING -Dexcept_EXPORTS -I$(CXXWRAP_HOME)/include -I$(JULIA_HOME)/include/julia 
CXXFLAGS+= -I./pcm #-DPCM_USE_PERF

vpath %.cpp ./pcm .

LOAD_FLAGS= -L$(CXXWRAP_HOME)/lib/ -lcxxwrap_julia -L$(JULIA_HOME)/lib/ -ljulia

all: $(DIRECTORIES) lib/libpcm.so

lib/libpcm.so: $(OBJS)
	mkdir -p lib
	$(CXX) $(CXXFLAGS) -shared $^ -lpthread -o $@ $(LOAD_FLAGS)

build/%.o: %.cpp build
	$(CXX) $(CXXFLAGS) -c -o $@ $<

# Rules for directories
build:
	mkdir -p build

# Clean
clean:
	rm -rf build
	rm -rf lib

