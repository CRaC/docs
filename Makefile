all : spring-boot.png startup.png

%.png : openjdk.%.data crac.%.data perf.plot
	gnuplot -e 'title = "$*"' \
		-e 'openjdk = "openjdk.$*.data"' \
		-e 'crac = "crac.$*.data"' \
		-e 'output = "$@"' \
		perf.plot

startup.png : startup.data startup.plot
	gnuplot startup.plot

clean:
	rm -f *.png
