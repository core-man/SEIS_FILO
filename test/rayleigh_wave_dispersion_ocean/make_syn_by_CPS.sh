#!/bin/bash

model_file=../vmod/CPS_ocean.mod #CPS_input.mod
distance_file=distance_file

sprep96 -M $model_file -d $distance_file -R -NMOD 8
sdisp96
sdpsrf96 -R -TXT

