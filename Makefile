PUB=/usr/lib/dart/bin/pub
DART=dart

.PHONY = release debug clean

clean:
	-rm -fr build/


release:
	${PUB} build --mode release

debug:
	${PUB} build --mode debug

get:
	${PUB} get

webserver_ddc:
	$(PUB) serve web/ --web-compiler=dartdevc
