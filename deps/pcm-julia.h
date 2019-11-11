#ifndef PCM_JULIA_HEADERS
#define PCM_JULIA_HEADERS

#include <tuple>
#include <iostream>

#include "pcm/cpucounters.h"

class CounterWrapper
{
    public:
        std::vector<CoreCounterState> core_counters_before;
        std::vector<CoreCounterState> core_counters_after;
        std::vector<SocketCounterState> socket_counters_before;
        std::vector<SocketCounterState> socket_counters_after;
        SystemCounterState system_counters_before;
        SystemCounterState system_counters_after;

    void sample(PCM* m) {
        // Swap the before and after states
        std::swap(core_counters_before, core_counters_after);
        std::swap(socket_counters_before, socket_counters_after);
        std::swap(system_counters_before, system_counters_after);

        m->getAllCounterStates(system_counters_after, 
                               socket_counters_after, 
                               core_counters_after);
    }

    std::tuple<int64_t, int64_t, int64_t, int64_t> aggregate_counters(PCM* m,
                                                                      int64_t* cores,
                                                                      int64_t len)
    {
        // Aggregate across all cores.
        int64_t a[4] = {0, 0, 0, 0};
        for (size_t i = 0; i < 4; i++)
        {
            for (int64_t j = 0; j < len; j++)
            {
                a[i] += getNumberOfCustomEvents(i,
                                                core_counters_before[cores[j]],
                                                core_counters_after[cores[j]]);
            }
        }

        return std::make_tuple(a[0], a[1], a[2], a[3]);
    }
};

#endif
