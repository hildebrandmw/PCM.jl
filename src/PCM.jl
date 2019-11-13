module PCM

using CxxWrap

include("lib.jl")
using .Lib

reset() = Lib.resetPMU(Lib.getInstance())
cleanup() = Lib.cleanup(Lib.getInstance())

const MAX_CUSTOM_EVENTS = convert(Int, Lib.getMaxCustomCoreEvents(Lib.getInstance()))

#####
##### General Queries
#####

pcm() = Lib.getInstance()
numcores() = convert(Int, Lib.getNumCores(pcm()))

#####
##### Core Counters
#####

struct EventDescription
    event_number::Int64
    umask_value::Int64
    name::Symbol

    function EventDescription(event::Integer, umask::Integer, name = :unknown_event)
        return new(
            convert(Int64, event),
            convert(Int64, umask),
            name
        )
    end
end

function Base.show(io::IO, E::EventDescription)
    print(
        io,
        "PCM Event \'$(E.name)\'-- event: 0x",
        string(E.event_number; base = 16),
        ", umask: 0x",
        string(E.umask_value; base = 16),
    )
    return nothing
end

mutable struct CoreMonitor
    pcm::Lib.PCMRef
    wrapper::Lib.CounterWrapperAllocated
    cores::Vector{Int64}
    events::Vector{EventDescription}

    # Inner constructore - need to get the reference to the singular PCM instance as well
    # as instantiate a `CounterWrapper` for storing counter values.
    function CoreMonitor(; cores::AbstractVector = 1:numcores())
        pcm = Lib.getInstance()
        wrapper = Lib.CounterWrapper()

        # Do some processing on the on the `cores` argument - make sure all values are
        # within the valid core range, materialize it etc.
        cores = sort(Vector(cores))
        if first(cores) < 0
            throw(ArgumentError("Core numbers must be greater than zero"))
        end

        if last(cores) > numcores()
            throw(ArgumentError("Core numbers must be less than or equal to $(numcores())"))
        end

        # Subtract 1 from everything since we're using this to talk with the C++ code.
        cores .= cores .- 1

        monitor = new(
            pcm,
            wrapper,
            cores,
            EventDescription[],
        )

        return monitor
    end
end

function program(monitor::CoreMonitor, events::Vector{EventDescription})
    original_size = length(events)

    # If more than MAX_CUSTOM_EVENTS events are provided, throw an error.
    if length(events) > MAX_CUSTOM_EVENTS
        err = ArgumentError("Number of events must be less than or equal to 4!")
        throw(err)
    end

    # Fill out vector of event descriptions if not enough are provided.
    # This needs to be of length 4 because PCM is not the best coded thing in the world.
    while length(events) < 4
        push!(events, EventDescription(0, 0))
    end

    # Convert the array of structs into two arrays
    event_numbers = [i.event_number for i in events]
    umask_values = [i.umask_value for i in events]
    resize!(events, original_size)

    # Program the event counters.
    err = Lib.program(monitor.pcm, event_numbers, umask_values)

    if err == Lib.PCM_MSRAccessDenied
        throw(error("Cannot Access MSR"))
    elseif err == Lib.PCM_PMUBusy
        throw(error("PMU is Busy"))
    elseif err == Lib.PCM_UnknownError
        throw(error("Unknow Error!"))
    end

    monitor.events = events

    # Sample twice to initialize the counter arrays
    sample!(monitor)
    sample!(monitor)

    return err
end

# Swap the double-buffered counters and store the current counter state into the `after`
# set of counters.
sample!(monitor::CoreMonitor) = Lib.sample(monitor.wrapper, monitor.pcm)

# Get the values of the counters in `monitor`.
function getcounters(monitor)
    cores = monitor.cores
    values = Lib.aggregate_counters(monitor.wrapper, monitor.pcm, cores, length(cores))

    return collect(values)[1:length(monitor.events)]
end

#####
##### Uncore Counters
#####

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
    _sample!(pcm, before)
    _sample!(pcm, after)

    obj = UncoreMemoryMonitor(
        pcm,
        before,
        after,
        num_memory_controllers,
        num_memory_channels,
        Lib.getNumSockets(pcm)
    )
end

function sample!(U::UncoreMemoryMonitor)
    # Swap before and after state.
    U.before, U.after = U.after, U.before

    # Fill the new `after` state with the values of the counters.
    _sample!(U.pcm, U.after)
    return nothing
end

function _sample!(m::Lib.PCMRef, counters::Vector{Lib.ServerUncorePowerState})
    empty!(counters)
    for i in 1:Lib.getNumSockets(m)
        push!(counters, Lib.getServerUncorePowerState(m, i-1))
    end
end

function getcounter(U::UncoreMemoryMonitor, counter, socket)
    return getcounter(U.before, U.after, counter, U.num_memory_channels, socket + 1)
end

function getcounter(before, after, counter, nchannels, socket)
    return map(1:nchannels) do i
        x = Lib.getMCCounter(
            i-1,                    # memory channel
            convert(Int, counter),  # counter number
            before[socket],         # before uncore counter state
            after[socket],          # after uncore counter state
        )

        # normalize return value
        return convert(Int, x)
    end
end

end # module

