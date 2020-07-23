set terminal pngcairo enhanced font "Arial,12" fontscale 1.0 size 800, 500
set output "startup.png"

set samples 600, 600

set title "Time to first operation"
set xlabel "ms"

set offset 0,0,10,10
barwidth = 2.0
barspace = -10.0

unset border
set tics scale 0
set grid #noxtics nomxtics ytics
set style fill solid noborder
set xtics 1000

set ytics offset 0,first -barwidth/2
plot \
'startup.data' using ($2*0.5):($0*barspace+1*barwidth):($2*0.5):(barwidth/2):yticlabel(1) title "OpenJDK" with boxxyerrorbars linecolor rgb "red" , \
'startup.data' using ($2+20):($0*barspace+1*barwidth):2 with labels left notitle, \
'startup.data' using ($3*0.5):($0*barspace+0*barwidth):($3*0.5):(barwidth/2) title "OpenJDK on CRaC" with boxxyerrorbars linecolor rgb "blue", \
'startup.data' using ($3+20):($0*barspace+0*barwidth):3 with labels left notitle

