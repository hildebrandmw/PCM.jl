module Lib

using CxxWrap

const SRCDIR = @__DIR__
const PKGDIR = dirname(SRCDIR)
const DEPSDIR = joinpath(PKGDIR, "deps")

@wrapmodule(joinpath(DEPSDIR, "lib", "libpcm.so"))

function __init__()
    @initcxx
end

end
