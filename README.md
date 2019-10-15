# PCM

![Lifecycle](https://img.shields.io/badge/lifecycle-experimental-orange.svg)<!--
![Lifecycle](https://img.shields.io/badge/lifecycle-maturing-blue.svg)
![Lifecycle](https://img.shields.io/badge/lifecycle-stable-green.svg)
![Lifecycle](https://img.shields.io/badge/lifecycle-retired-orange.svg)
![Lifecycle](https://img.shields.io/badge/lifecycle-archived-red.svg)
![Lifecycle](https://img.shields.io/badge/lifecycle-dormant-blue.svg) -->
[![Build Status](https://travis-ci.com/hildebrandmw/PCM.jl.svg?branch=master)](https://travis-ci.com/hildebrandmw/PCM.jl)
[![codecov.io](http://codecov.io/github/hildebrandmw/PCM.jl/coverage.svg?branch=master)](http://codecov.io/github/hildebrandmw/PCM.jl?branch=master)

## Making Performance Counters Visible

To make performance counters visible to a general user (as opposed to a super user), you
will need to perform the following steps.

(1) Make MSR registers publically readable and writable.
```
sudo chmod o+r,o+w /dev/cpu/*/msr
```
