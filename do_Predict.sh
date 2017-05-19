#!/bin/bash
# sh do_Predict.sh $1 $2
# sh do_Predict.sh hg19 input
# $1: species could be hg19, mm10 or dm3
# $2 : input file for prediction, e.g. nbt.test or hg19.test
# input file should be in the libsvm string format. e.g. label	DNA_seq
source /etc/bashrc

cores=$(nproc)
export OMP_NUM_THREADS=$cores

species=$1 

if [ ! $species == "hg19" ] && [ ! $species == "mm10" ] && [ ! $species == "dm3" ]; then
	echo -e "Only hg19, mm10 and dm3 is valid!\n"
	exit
fi

## train
#one-class classification, using positve data alone,i.e. editing events
if [ ! -s $1_1Class_nu01.model ]; then
	sed '/-1/d' data/$1.train > data/$1.train.positives
	echo -e "\nTraining using one class...\n"
	./svm-train -s 2 -t 5 -z 0.2 -x 20 -y 20 -n 0.1 -q data/$1.train.positives $1_1Class_nu01.model
fi
#normal binary classification, uisng both positves and negatives
if [ ! -s $1.model ]; then
	echo -e "Training using both classes...\n"
	if [ $species == "hg19" ];then
		./svm-train -t 5 -z 0.2 -x 20 -y 20 -q data/$1.train $1.model
	fi
	if [ $species == "mm10" ];then
		./svm-train -t 5 -z 0.2 -x 20 -y 20 -w1 1.92 -w-1 1 -q data/$1.train $1.model
	fi
	if [ $species == "dm3" ];then
		./svm-train -t 5 -z 0.5 -x 20 -y 20 -w1 2.31 -w-1 1 -q data/$1.train $1.model
	fi
fi
##

echo -e "\nPredicting...\n"

filename=$(basename "$2")
odir="${filename%.*}"
mkdir -p $odir

# test
#human one class
./svm-predict -z 0.2 -x 20 -y 20 -q $2 $1_1Class_nu01.model $odir/pred.1Class.rst
#human binary classes
./svm-predict -z 0.2 -x 20 -y 20 -q $2 $1.model $odir/pred.2Classes.rst

if [ -s $odir/pred.1Class.rst ] && [ -s $odir/pred.2Classes.rst ]; then
	echo -e "InputLabel\tOne_Class_Pred_rst\tBinary_Classes_Pred_rst\tConsensus_rst" > $odir/pred.rst
	paste $2 $odir/pred.1Class.rst $odir/pred.2Classes.rst | awk -F"[ \t]" '{if($3==$4) print $1,$3,$4,$3; else print $1,$3,$4,"NA"}' OFS="\t" >> $odir/pred.rst
	rm $odir/pred.1Class.rst $odir/pred.2Classes.rst
fi

echo -e "Done!\n"