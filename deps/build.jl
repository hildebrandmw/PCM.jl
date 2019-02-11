using CxxWrap, LibGit2

# Path to the CxxWrap dependencies
cxxhome = dirname(dirname(CxxWrap.jlcxx_path))

url = "https://github.com/opcm/pcm"
branch = "master"
localdir = joinpath(@__DIR__, "pcm")
ispath(localdir) || LibGit2.clone(url, localdir; branch = branch)

juliahome = dirname(Base.Sys.BINDIR)
run(`make JULIA_HOME=$juliahome CXXWRAP_HOME=$cxxhome -j all `)
