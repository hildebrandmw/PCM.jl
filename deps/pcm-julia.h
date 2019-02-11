// From PCM
#ifndef PCM_JULIA_HEADERS
#define PCM_JULIA_HEADERS

#include "pcm/cpucounters.h"

class CounterWrapper
{
    std::vector<CoreCounterState> core_counters_1;
    std::vector<CoreCounterState> core_counters_2;
    std::vector<SocketCounterState> socket_counters_1;
    std::vector<SocketCounterState> socket_counters_2;
    SystemCounterState system_counters_1;
    SystemCounterState system_counters_2;

public:
    void sample(PCM * m);
    uint64_t incomingQPILinkBytes(uint32 socketNr, uint32 linkNr) const;
    uint64_t outgoingQPILinkBytes(uint32 socketNr, uint32 linkNr) const;
};

#endif
