all : startup.png spring-boot.png quarkus.png micronaut.png xml-transform.png

%.png : %.data perf.plot
	gnuplot -e 'title = "$*"' \
		-e 'datafile = "$*.data"' \
		-e 'output = "$@"' \
		perf.plot

startup.png : startup.data startup.plot
	gnuplot startup.plot

clean:
	rm -f *.png
