## Test environments

* local windows 10, R 3.5.0
* win-builder (devel and release)
* ubuntu 14.04.5 lts (on travis-ci), R 3.4.2
* windows server 2012 r2 x64 (build 9600), R 3.5.0 (on appveyor)

## R CMD check results

There were no ERRORS or WARNINGS.

There was one note regarding the width of a line exceeding 100 characters. In that case, this is due to using a (necessary) long url string in one example. This could be solved be using url shorteners, but I prefer not use a shortener because users would not be able to see what link would be loaded in the first place.
