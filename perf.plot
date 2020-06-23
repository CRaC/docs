title = title
openjdk = openjdk
crac = crac
output = output

#if (!exists("title"))   title   = "Spring Boot"
#if (!exists("openjdk")) openjdk = "openjdk.data"
#if (!exists("crac"))    crac    = "crac.data"
#if (!exists("output"))  output  = "spring-boot.png"

set terminal pngcairo enhanced font "Arial,12" fontscale 1.0 size 800, 600
set output output

set samples 600, 600

set autoscale
#set logscale xy
#set logscale x
#set logscale y 5

set title "Time to complete N operations: ".title
set key left top
set xlabel "Requests"
set ylabel "Secs"
x = 0.0

unset border
set tics scale 0
set grid #noxtics nomxtics ytics

set style data linespoints
set pointsize 0.75
plot \
openjdk using 1:2 title 'OpenJDK' pointtype 7 lw 3 linecolor rgb "red", \
crac using 1:2 title 'OpenJDK on C/RaC' pointtype 7 lw 3 linecolor rgb "blue"
