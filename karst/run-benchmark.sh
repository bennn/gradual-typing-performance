# Just run qsub with the qscript
if [ $# -eq 1 ]; then
  RACKET_VERSION=$1
  qsub -k o -l nodes=1:ppn=16,walltime=24:00:00 qscript.sh
else
  echo "Usage: run-benchmark.sh <RACKET-VERSION>"
fi
