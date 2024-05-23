title = title
datafile = datafile
output = output

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
datafile using 1:2 title 'OpenJDK' pointtype 7 lw 3 linecolor rgb "red", \
datafile using 1:3 title 'OpenJDK on CRaC' pointtype 7 lw 3 linecolor rgb "blue"
