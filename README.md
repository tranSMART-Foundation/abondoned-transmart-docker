# transmart-docker
This project suports a docker image for the tranSMART Foundation's transmartApp. 
The work here-in borrows heavily from https://github.com/io-informatics/transmart-docker 
and https://github.com/quartzbio/transmart-docker (both licensed under the terms of the 
[GPLv3](http://opensource.org/licenses/GPL-3.0) License.)

See also, the LICENSE file in this repository.

This is intended only for demo, testing and/or proof of concept of the tranSMART platform.
The image contains everything you need to deploy and use the tranSMART platform
from a single Docker container (e.g. on a single VM). For a more flexable 
implementation (using multiple containers/VMs), 
see the transmart-docker repository by io-informatics, referenced above.

To use this docker image, install [docker](https://www.docker.com/) on the target host,
obtain the [zip file](https://github.com/tranSMART-Foundation/transmart-docker/archive/master.zip) 
of this repository, expand it in the directory of your choice, start the docker shell,
change directory to that directory, and type the 
