set term postscript enhanced eps color 32 font "Arial"
set output "rel-1e-2-decompress.eps"
set boxwidth 0.99 relative
set style fill solid 0.00 border 0
set style data histogram
set format y "%g"
set yrange [0:650]
set ylabel "Throughput (GB/s)" font ",60" off -2,-2
#set xlabel "Benchmarks" font ",60" 
set bmargin screen 0.30
set tmargin 3
set lmargin 9

set label 1 "1072.85" at 4.9,550 font ",45"
set label 2 "834.55" at 6.1,550 font ",45"
set label 3 "1241.59" at 0.9,550 font ",45"
set label 4 "1188.03" at 2.1,550 font ",45"
set label 5 "709.33" at 6.9,550 font ",45"
set label 6 "697.31" at 8.0,550 font ",45"

set arrow 1 from 5.4,580 to 5.7,640 lw 3 lt 1 lc rgb "#000000"
set arrow 2 from 6.2,580 to 6.0,640 lw 3 lt 1 lc rgb "#000000"
set arrow 3 from 1.4,580 to 1.7,640 lw 3 lt 1 lc rgb "#000000"
set arrow 4 from 2.2,580 to 2.0,640 lw 3 lt 1 lc rgb "#000000"
set arrow 5 from 7.4,580 to 7.7,640 lw 3 lt 1 lc rgb "#000000"
set arrow 6 from 8.2,580 to 8.0,640 lw 3 lt 1 lc rgb "#000000"

set grid ytics
set xtics rotate by 20 right font ",60" off 4,0
set ytics font ",60" 100
set key top Left reverse font ",60" spacing 2 samplen 2
set size 3.4,1.5
set key outside top horizontal center
set key at 4.3,800
plot "yafan.txt" \
                using 2:xtic(1) ti "cuSZp2-P" fs pattern 3 lt -1 lc rgb '#a469bd' lw 4, \
            ""  using 3:xtic(1) ti "cuSZp2-O" fs pattern 3 lt -1 lc rgb '#5dade2' lw 4, \
            ""  using 4:xtic(1) ti "cuZFP" fs pattern 3 lt -1 lc rgb '#f6da65' lw 4, \
            ""  using 5:xtic(1) ti "FZ-GPU" fs pattern 3 lt -1 lc rgb '#ffbca7' lw 4, \
            ""  using 6:xtic(1) ti "cuSZp" fs pattern 3 lt -1 lc rgb '#91e9d0' lw 4


#""  using 0:2:2 ti "" with labels rotate by 20 font ",40" off -2,0.7, \
#""  using 0:5:5 ti "" with labels rotate by 20 font ",40"  off 4,0.5