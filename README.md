bash-outlogger
==============

![shellcheck](https://github.com/MADhacking/bash-outlogger/workflows/Shellcheck/badge.svg) ![tests](https://github.com/MADhacking/bash-outlogger/workflows/Ebuild%20Tests/badge.svg) [![coverage](https://codecov.io/gh/MADhacking/bash-outlogger/branch/master/graph/badge.svg)](https://codecov.io/gh/MADhacking/bash-outlogger)

A great many bash scripts require some simple output and error logging facilities such as redirecting the output of a single command or multiple commands to a file or running an application whilst simultaneously recording the output to a file and displaying it to the screen.

The bash-outlogger package provides this functionality and also provides the ability to compress large log-files, using the bzip2 compression utility, and email the resulting log-files as attachments to users using the mutt email client. 

More details and example code can be found at

http://www.mad-hacking.net/software/linux/agnostic/bash-outlogger/index.xml
