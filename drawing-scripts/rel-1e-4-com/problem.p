set term postscript enhanced eps color 32 font "Arial"
set output "rel-1e-4-compress.eps"
set boxwidth 0.99 relative
set style fill solid 0.00 border 0
set style data histogram
set format y "%g"
set yrange [0:450]
set ylabel "Throughput (GB/s)" font ",60" off -2,-2
#set xlabel "Benchmarks" font ",60" 
set bmargin screen 0.30
set tmargin 3
set lmargin 9

set label 1 "553.74" at 5.0,370 font ",45"
set label 2 "544.7" at 6.1,370 font ",45"
set arrow 1 from 5.4,400 to 5.7,450 lw 3 lt 1 lc rgb "#000000"
set arrow 2 from 6.2,400 to 6.0,450 lw 3 lt 1 lc rgb "#000000"

set grid ytics
set xtics rotate by 20 right font ",60" off 4,0
set ytics font ",60" 70
set key top Left reverse font ",60" spacing 2 samplen 2
set size 3.4,1.5
set key outside top horizontal center
set key at 4.3,555
plot "yafan.txt" \
                using 2:xtic(1) ti "cuSZp2-P" fs pattern 3 lt -1 lc rgb '#a469bd' lw 4, \
            ""  using 3:xtic(1) ti "cuSZp2-O" fs pattern 3 lt -1 lc rgb '#5dade2' lw 4, \
            ""  using 4:xtic(1) ti "cuZFP" fs pattern 3 lt -1 lc rgb '#f6da65' lw 4, \
            ""  using 5:xtic(1) ti "FZ-GPU" fs pattern 3 lt -1 lc rgb '#ffbca7' lw 4, \
            ""  using 6:xtic(1) ti "cuSZp" fs pattern 3 lt -1 lc rgb '#91e9d0' lw 4


#""  using 0:2:2 ti "" with labels rotate by 20 font ",40" off -2,0.7, \
#""  using 0:5:5 ti "" with labels rotate by 20 font ",40"  off 4,0.5