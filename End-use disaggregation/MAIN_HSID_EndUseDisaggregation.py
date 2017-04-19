# -*- coding: utf-8 -*-

# This is the main file to perform end-use disaggregation with the HSID algorithm published in
#
# " Cominola, A., Giuliani, M., Piga, D., Castelletti, A., & Rizzoli, A. E. (2017). 
# A Hybrid Signature-based Iterative Disaggregation algorithm for Non-Intrusive Load Monitoring. 
# Applied Energy, 185, 331-344. " If you use this code you must cite this journal paper.
# 
# 
# Requirements for running this code: 
#
#   - the HSID algorithm requires the installation of the NILM toolkit v0.2 (http://nilmtk.github.io/), 
#     developed by Batra et al. "Batra N, Kelly J, Parson O, Dutta H, Knottenbelt W, Rogers A, et al. NILMTK: an
#     open source toolkit for non-intrusive load monitoring. In: Proceedings of the
#     5th international conference on future energy systems. ACM; 2014. p. 265–76." Part of this script is inspired by 
#     the code in the NILMTK and the HMM module of Python scikit-learn machine learning library is exploited for FHMM resolution.
#     Credits are given to the authors of NILMTK for the FHMM module of the HSID algorithm.
#
#   - the ISDTW part of HSID algorith requires the "Python extension for UCR Suite highly optimized subsequence search
#     using Dynamic Time Warping (DTW)" (https://github.com/klon/ucrdtw).
#
#   - after installation of the NILMTK, this script must be run from the '/nilmtk-master' directory.
#  
#   - after installation of the NILMTK, the folder 'postprocessing' provided with this script must be integrated in the NILMTK. It 
#     must be placed in the '/nilmtk-master/nilmtk' directory, together with its content. It contains the functions needed to perform ISDTW 
#     end-use event correction as described in Cominola et al. (2017, see above).
#   
#   - input data for each applpiance must be organized as .csv files according to the standards of AMPds (http://ampds.org/) dataset set in the 
#     NILMTK by Batra et al. (2014), and must be placed in the 'data/AMPds/electricity' directory.
#   
#   - end-use signatures file are needed to run the ISDTW part of HSID algorithm (Cominola et al., 2017). They must be placed in the 
#     'data/AMPds/electricity/signatures/' directory as .txt files. 
#
# Copyright: Andrea Cominola
# Last modified: Andrea Cominola, Apr 2017


# Importing useful libraries
from nilmtk.dataset import ampds
from nilmtk.disaggregate.fhmm_exact import FHMM
import json
import pandas as pd 
from pandas import HDFStore
from nilmtk.dataset.ampds import Measurement
import nilmtk.preprocessing.electricity.building as prepb
from nilmtk.cross_validation import train_test_split
import os 
import time
from sklearn.metrics import f1_score
import numpy as np
import csv
import warnings 
from nilmtk.postprocessing import iterativeDTW
warnings.filterwarnings('ignore')

### ---------- Initializing settings ---------- #

nApp = 5 # This is the number of appliances to consider. This parameter should be set by the user.
eventlength=10 # This specifies the length of single events for splitting consumption trajectories and applying ISDTW.

# Setting dataset type and path
dataset = ampds.AMPDS()
PATH = 'data/AMPds/'

# Feature to perform disaggregation on
DISAGG_FEATURE = Measurement('power', 'active')

# Load data
dataset.load_electricity(PATH)

# Get data of Home_01
building = dataset.buildings[1]

# Preprocessing:
print(' :::::::::: Dividing data into test and train')
lenToUse = len(building.utility.electric.appliances.items()[0][1]);
train, test = train_test_split(building, train_size = lenToUse/2, test_size = lenToUse/2) # This splits the dataset in 1/2 for training and 1/2 for testing. Test-training ratio should be set by users


###  ---------- Disaggregation with FHMM ---------- #

#  --- training model
disaggregator = FHMM()
disaggregator_name = "FHMM"
print(' :::::::::: Training FHMM disaggregator')
t1 = time.time()
disaggregator.train(train, disagg_features=[DISAGG_FEATURE])
t2 = time.time()
print("Runtime to train for {} = {:.2f} seconds".format(disaggregator_name, t2 - t1))
train_time=t2-t1
    
# --- disaggregation
print(' :::::::::: Starting disaggregation')
t1 = time.time()
disaggregator.disaggregate(test)
t2 = time.time()
print("Runtime to disaggregate for {}= {:.2f} seconds".format(disaggregator_name, t2 - t1))
disaggregate_time=t2-t1   
        
# Predicted power and states
# Predicted power is a DataFrame containing the predicted power of different 
# appliances
predicted_power = disaggregator.predictions
app_ground = test.utility.electric.appliances
ground_truth_power = pd.DataFrame({appliance: app_ground[appliance][DISAGG_FEATURE] for appliance in app_ground})

### --- saving outputs to txt files
# ground truth power
print(' :::::::::: Saving groundtruth output')
outputFile = "OUTPUT_FHMM/groundtruth.txt"
np.savetxt(outputFile, ground_truth_power)

###  ---------- Loading Iterative Subsequence Dynamic Time Warping (ISDWR) and performing corrections to FHMM end-use estimates ---------- #

###  DTW support functions definition ###
# Chunk splitter function. 
def gen_events(dataserie, eventlength): 
    event=list()
    for i,line in enumerate(dataserie):
        if(i % eventlength==0 and i>0):
            yield event
            del event[:]
        event.append(line)
    yield event
    return
# ------------------------------------------------ #

print(' :::::::::: Initializing ISDTW')
postprocessor=iterativeDTW.DTW();

# Loading signature data
print(' :::::::::: Loading end-use signatures')
PATH = 'data/AMPds/electricity/signatures/' # This is the path were .txt files with end-use signatures should be placed
postprocessor.load_signatures(PATH)
totConsumption=test.utility.electric.get_dataframe_of_mains().power.active

# Reordering predictions
newPredictions=[]
i=0
for signature in postprocessor.signatures:
    sigName=signature.name
    sigInstance=signature.instance
    for j in range(nApp):
        predName=predicted_power.columns.values.tolist()[j][0]
        predNumber=predicted_power.columns.values.tolist()[j][1]
        if sigName==predName and sigInstance==predNumber:
            newPredictions.append(predicted_power.values[:,j])

predictions=newPredictions
print(' :::::::::: Saving FHMM output files')
outputFile = "OUTPUT_FHMM/out_FHMM.txt" # Saving output of FHMM end-use disaggregation
np.savetxt(outputFile, newPredictions)

predictions=np.loadtxt(outputFile)

# Performing corrections
print(' :::::::::: Performing ISDTW corrections')
predictionsCorrected=[]
currentPredictions=[]
t1=time.time()
posInit=0
posFin=posInit+eventlength-1
k=0

minPred=[]
maxPred=[]
meanPred=[]
predCorr=[]
diffPred=[]

# Evaluating statistics for end-use FHMM predictions
for i in range(nApp):
    minPredTemp=np.min(np.unique(predictions[i]))
    maxPredTemp=np.max(np.unique(predictions[i]))
    meanPredTemp=np.mean(predictions[i])
    maxPred.append(maxPredTemp)
    minPred.append(minPredTemp)
    meanPred.append(meanPredTemp)
    diffPred.append(maxPredTemp-minPredTemp)

# Performing actual ISDTW corrections
for event in gen_events(totConsumption, eventlength):
    print(k)
    domIndex=postprocessor.dominanceRanking(predictions[:,posInit:posFin], nApp, diffPred, minPred) # Dominance ranking
    predCorr=postprocessor.correctPower_singleEvent(predictions, nApp, domIndex, totConsumption, posInit, posFin, event, eventlength, predCorr, minPred, maxPred, diffPred, meanPred) # ISDWT corrections
    posInit=posFin+1
    posFin=posInit+eventlength-1
    del domIndex
    k+=1

t2=time.time()
print("Runtime to perform ISDWT corrections = {:.2f} ".format(t2 - t1))
correction_time=t2-t1

print(' :::::::::: Saving DTW output files')
outputFile = "OUTPUT_FHMM/out_FHMM_ISDTW.txt"
np.savetxt(outputFile, predCorr)
