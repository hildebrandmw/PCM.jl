/////
///// Julia Wrappers
/////

#include <iostream>
#include <algorithm>
#include <tuple>

// Julia CXX wrap
#include "pcm-julia.h"
#include "pcm/cpucounters.h"

#include "jlcxx/jlcxx.hpp"
#include "jlcxx/tuple.hpp"

namespace jlcxx
{
    template<> struct IsBits<PCM::ErrorCode> : std::true_type {};
    template<> struct IsBits<PCM::ProgramMode> : std::true_type {};
}

JLCXX_MODULE define_julia_module(jlcxx::Module& mod)
{
    // errorcode Enum
    mod.add_bits<PCM::ErrorCode>("PCM_ErrorCode");
    mod.set_const("PCM_Success", PCM::Success);
    mod.set_const("PCM_MSRAccessDenied", PCM::MSRAccessDenied);
    mod.set_const("PCM_PMUBusy", PCM::PMUBusy);
    mod.set_const("PCM_UnknownError", PCM::UnknownError);

    // return the maximum number of memory channels
    mod.method("maxchannels", [](){ return (int64_t)ServerUncorePowerState::maxChannels; });

    /////
    ///// core events
    /////

    // note: length of `event_numbers` and `umask_values` must both be 4!!
    // julia code will manage this.
    mod.method("program", [](
            PCM* m,
            int64_t* event_numbers,
            int64_t* umask_values)
    {
        // construct events from the passed numbers and masks.
        PCM::CustomCoreEventDescription events[4];
        for (int i = 0; i < 4; i++)
        {
            events[i].event_number = event_numbers[i];
            events[i].umask_value = umask_values[i];
        }
        return m->program(PCM::CUSTOM_CORE_EVENTS, &events);
    });

    mod.add_type<CounterWrapper>("CounterWrapper")
        .method("read_counters", &CounterWrapper::read_counters);

    // ProgramMode enum
    mod.add_bits<PCM::ProgramMode>("ProgramMode");
    mod.set_const("DEFAULT_EVENTS", PCM::DEFAULT_EVENTS);
    mod.set_const("CUSTOM_CORE_EVENTS", PCM::CUSTOM_CORE_EVENTS);
    mod.set_const("EXT_CUSTOM_CORE_EVENTS", PCM::EXT_CUSTOM_CORE_EVENTS);
    mod.set_const("INVALID_MODE", PCM::INVALID_MODE);

    // Wrap the Uncore Counter
    mod.add_type<ServerUncorePowerState>("ServerUncorePowerState");

    // For these counter methods, we need to wrap the actual function call into a lambda
    // becauce Julia can't infer `uint64` correctly (it infers to `Any` which leads to
    // a segfault. Instead, we have to cast the return to a `uint64_t`, which seems
    // to work out alright
    mod.method("getMCCounter", [](
            uint32_t channel,
            uint32_t counter,
            ServerUncorePowerState& before,
            ServerUncorePowerState& after)
    {
        return (uint64_t) getMCCounter(channel, counter, before, after);
    });

    // PCM Type
    mod.add_type<PCM>("PCM")
        .method("getInstance", &PCM::getInstance)
        // Queries
        .method("getNumCores", &PCM::getNumCores)
        .method("getNumSockets", &PCM::getNumSockets)
        .method("getQPILinksPerSocket", &PCM::getQPILinksPerSocket)
        .method("getMCChannels", &PCM::getMCChannels)
        .method("getMaxCustomCoreEvents", &PCM::getMaxCustomCoreEvents)
        // Misc Stuff
        .method("resetPMU", &PCM::resetPMU)
        .method("cleanup", &PCM::cleanup)
        // Uncore
        .method("programServerUncoreMemoryMetrics", &PCM::programServerUncoreMemoryMetrics)
        .method("getServerUncorePowerState", &PCM::getServerUncorePowerState);
}
