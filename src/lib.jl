module Lib

using CxxWrap

const SRCDIR = @__DIR__
const PKGDIR = dirname(SRCDIR)
const DEPSDIR = joinpath(PKGDIR, "deps")

@wrapmodule(joinpath(DEPSDIR, "lib", "libpcm.so"))

function __init__()
    @initcxx
end

# Supply default arguments to `program`.
program(p::PCMRef) = program(p, DEFAULT_EVENTS, CxxWrap.ConstPtr{Nothing}(0))

## Note on Uncore counters
#
# Call as programServerUncoreMemoryMetrics(m, -1, -1, true) to get NVDIMM support
#
# From reading the source, the metrics can be retrieved via
#
#
# getMCCounter(serveruncore, i, 0) -> IMC Reads
# getMCCounter(serveruncore, i, 1) -> IMC Writes
# getMCCounter(serveruncore, i, 2) -> PMM Reads
# getMCCounter(serveruncore, i, 3) -> PMM Writes
#
# where `i` is the channel of interest. Note that if `i` is out of bounds, just 0 is returned
# so that is safe.

end
