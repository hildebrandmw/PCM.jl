module PCM

using CxxWrap

include("lib.jl"); using .Lib

reset() = Lib.resetPMU(Lib.getInstance())
cleanup() = Lib.cleanup(Lib.getInstance())

# Type for measuring Memory and PMM bandwidth
mutable struct UncoreMemoryMonitor
    pcm::Lib.PCMRef

    # Keep vectors of UncorePowerStates, one for each socket.
    # We will swap these back and forth to get the deltas of the metrics we are measuring.
    before::Vector{Lib.ServerUncorePowerState}
    after::Vector{Lib.ServerUncorePowerState}

    # Some statistics for performance

    # Number of memory controllers
    num_memory_controllers::Int64 
    num_memory_channels::Int64
    num_sockets::Int64
end

function UncoreMemoryMonitor(num_memory_controllers, num_memory_channels)
    # Instantiate the PCM struct and program the memory controller counters
    pcm = Lib.getInstance()
    Lib.programServerUncoreMemoryMetrics(pcm, -1, -1, true)

    # Instantiate the dual arrays for sampling and do a quick sample so
    before = Vector{Lib.ServerUncorePowerState}()
    after = Vector{Lib.ServerUncorePowerState}()
    sample_uncore!(pcm, before)
    sample_uncore!(pcm, after)

    obj = UncoreMemoryMonitor(
        pcm, 
        before, 
        after, 
        num_memory_controllers, 
        num_memory_channels, 
        Lib.getNumSockets(pcm)
    )
end

function sample_uncore!(m::Lib.PCMRef, counters::Vector{Lib.ServerUncorePowerState})
    empty!(counters)
    for i in 1:Lib.getNumSockets(m)
        push!(counters, Lib.getServerUncorePowerState(m, i-1))
    end
end

function sample!(U::UncoreMemoryMonitor)
    U.before, U.after = U.after, U.before
    sample_uncore!(U.pcm, U.after)
    return nothing
end

@enum CounterVals::Int32 READ=0 WRITE=1 PMM_READ=2 PMM_WRITE=3
Base.convert(::Type{T}, c::CounterVals) where {T <: Integer} = T(c)

dram_reads(U::UncoreMemoryMonitor, socket)  = getcounter(U.before, U.after, READ, U.num_memory_channels, socket + 1)
dram_writes(U::UncoreMemoryMonitor, socket) = getcounter(U.before, U.after, WRITE, U.num_memory_channels, socket + 1)
pmm_reads(U::UncoreMemoryMonitor, socket)   = getcounter(U.before, U.after, PMM_READ, U.num_memory_channels, socket + 1)
pmm_writes(U::UncoreMemoryMonitor, socket)  = getcounter(U.before, U.after, PMM_WRITE, U.num_memory_channels, socket + 1)

getcounter(U::UncoreMemoryMonitor, counter, socket) = getcounter(U.before, U.after, counter, U.num_memory_channels, socket + 1)

getcounter(before, after, counter, nchannels, socket) = 
    [convert(Int, Lib.getMCCounter(i-1, convert(Int, counter), before[socket], after[socket])) for i in 1:nchannels]

# This method was transcribed from "pcm/pcm-memory.cpp", line: 667-692
function pmm_hitrate(before, after, num_memory_channels, num_memory_controllers, idx)
    # Calculate the number of PMM groups 
    channels_per_controller = div(num_memory_channels, num_memory_controllers) 

    hitrates = zeros(Float64, num_memory_controllers)
    for controller in 0:num_memory_controllers-1

        # Accumulate the number of reads to this controller
        acc = 0
        for sub_channel in 0:channels_per_controller
            channel = channels_per_controller * controller + sub_channel
            acc += Lib.getMCCounter(channel, Int(READ), before[idx], after[idx])
        end

        # Now that this is accumulated, read from the M2M controller to get hit rate.
        hitrate = Lib.getM2MCounter(controller, 0, before[idx], after[idx]) / acc
        hitrates[controller + 1] = hitrate
    end
    return hitrates
end

# 
# 
# mutable struct PCMCounters
#     instance::Lib.PCMRef
#     wrapper::Lib.CounterWrapperAllocated
# end
# 
# 
# function PCMCounters()
#     # Get the PCM counter instance
#     pcm = Lib.getInstance()
#     Lib.program(pcm)
# 
#     # Program Uncore metrics, include PMM support
#     Lib.programServerUncoreMemoryMetrics(pcm, -1, -1, true)
#     before_state = Vector{Lib.ServerUncorePowerState}()
#     after_state = Vector{Lib.ServerUncorePowerState}()
#     sample_uncore!(pcm, before_state)
#     sample_uncore!(pcm, after_state)
# 
#     # Instantiate a CounterWrapper
#     wrapper = Lib.CounterWrapper() 
# 
#     # Sample a couple of times to ensure that the elements within `wrapper` are allocated
#     # and initialized
#     Lib.sample(wrapper, pcm)
#     Lib.sample(wrapper, pcm)
# 
#     # Attach a finalizer to ensure everything gets reset when this object goes out of scope.
#     obj = PCMCounters(pcm, wrapper, before_state, after_state)
#     finalizer(cleanup, obj)
#     return obj
# end
# 
# cleanup(c::PCMCounters) = Lib.cleanup(c.instance)
# function sample!(c::PCMCounters) 
#     # Update normal counters
#     Lib.sample(c.wrapper, c.instance)
# 
#     # Update uncore counters
#     c.before_state, c.after_state = c.after_state, c.before_state 
#     sample_uncore!(c.instance, c.after_state)
#     return nothing
# end
# 
# 
# """
#     incoming_upi_link_bytes(c::PCMCounters, socket, link)
# 
# Return the number of incoming UPI link bytes for `socket` and `link` between the two samples
# in `c`.
# """
# function incoming_upi_link_bytes(c::PCMCounters, socket, link)
#     return Lib.incomingQPILinkBytes(c.wrapper, socket, link)
# end
# 
# function outgoing_upi_link_bytes(c::PCMCounters, socket, link)
#     return Lib.outgoingQPILinkBytes(c.wrapper, socket, link)
# end

end # module
