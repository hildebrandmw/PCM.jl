/////
///// Julia Wrappers
/////

// Julia CXX wrapp
#include "pcm-julia.h"
#include "pcm/cpucounters.h"
#include "jlcxx/jlcxx.hpp"

void CounterWrapper::sample(PCM* m)
{
    std::swap(core_counters_1, core_counters_2);  
    std::swap(socket_counters_1, socket_counters_2);  
        std::swap(system_counters_1, system_counters_2);  
        m->getAllCounterStates(system_counters_2, socket_counters_2, core_counters_2);
    }

    uint64_t CounterWrapper::incomingQPILinkBytes(uint32 socketNr, uint32 linkNr) const
    {
        return  getIncomingQPILinkBytes(socketNr, linkNr, system_counters_1, system_counters_2);
    }
    uint64_t CounterWrapper::outgoingQPILinkBytes(uint32 socketNr, uint32 linkNr) const
    {
        return getOutgoingQPILinkBytes(socketNr, linkNr, system_counters_1, system_counters_2);
    }

    namespace jlcxx
    {
        template<> struct IsBits<PCM::ErrorCode> : std::true_type {};
        template<> struct IsBits<PCM::ProgramMode> : std::true_type {};
    }

    JLCXX_MODULE define_julia_module(jlcxx::Module& mod)
    {
        // Type for actually accessing the counters
        mod.add_type<CounterWrapper>("CounterWrapper")
            .method("sample", &CounterWrapper::sample)
            .method("incomingQPILinkBytes", &CounterWrapper::incomingQPILinkBytes)
            .method("outgoingQPILinkBytes", &CounterWrapper::outgoingQPILinkBytes);

        // ErrorCode Enum
        mod.add_bits<PCM::ErrorCode>("ErrorCode");
        mod.set_const("Success", PCM::Success);
        mod.set_const("MSRAccessDenied", PCM::MSRAccessDenied);
        mod.set_const("PMUBusy", PCM::PMUBusy);
        mod.set_const("UnknownError", PCM::UnknownError);

        // Return the maximum number of memory channels
        mod.method("maxchannels", [](){ return (int64_t)ServerUncorePowerState::maxChannels; });

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
        mod.method("getMCCounter", [](uint32_t channel, uint32_t counter, ServerUncorePowerState& before, ServerUncorePowerState& after)
            {
                return (uint64_t) getMCCounter(channel, counter, before, after);
            });

        mod.method("getM2MCounter", [](uint32_t channel, uint32_t counter, ServerUncorePowerState& before, ServerUncorePowerState& after)
            {
                return (uint64_t) getM2MCounter(channel, counter, before, after);
            });

        // PCM Type
        mod.add_type<PCM>("PCM")
            .method("getInstance", &PCM::getInstance)
            // Queries
            .method("getNumCores", &PCM::getNumCores)
            .method("getNumSockets", &PCM::getNumSockets)
            .method("getQPILinksPerSocket", &PCM::getQPILinksPerSocket)
            .method("getMCChannels", &PCM::getMCChannels)
            // API Stuff
            .method("program", &PCM::program)
            .method("resetPMU", &PCM::resetPMU)
        .method("cleanup", &PCM::cleanup)
        // Uncore
        .method("programServerUncoreMemoryMetrics", &PCM::programServerUncoreMemoryMetrics)
        .method("getServerUncorePowerState", &PCM::getServerUncorePowerState);
}
