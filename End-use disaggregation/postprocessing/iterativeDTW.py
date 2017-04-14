# Importing useful libraries
from nilmtk.dataset import ampds
from nilmtk.disaggregate.fhmm_exact import FHMM
from nilmtk.postprocessing.postprocessor import Postprocessor 
import json
import pandas as pd
from pandas import HDFStore
from nilmtk.dataset.ampds import Measurement, appliance_name_mapping
import nilmtk.preprocessing.electricity.building as prepb
from nilmtk.cross_validation import train_test_split
import os
import time
from sklearn.metrics import f1_score 
import numpy as np
import csv
import warnings
import glob
from nilmtk.sensors.electricity import ApplianceName
from collections import defaultdict
from random import randint 
import _ucrdtw

# Appliance name mapping
appliance_name_mapping = {
    'B1E': ApplianceName('bedroom misc', 1),
    'B2E': ApplianceName('bedroom misc', 2),
    'BME': ApplianceName('plugs', 1),
    'CDE': ApplianceName('dryer washer', 1),
    'CWE': ApplianceName('dryer washer', 2),
    'DNE': ApplianceName('plugs', 2),
    'DWE': ApplianceName('dishwasher', 1),
    'EBE': ApplianceName('workbench', 1),
    'EQE': ApplianceName('security', 1),
    'FGE': ApplianceName('fridge', 1),
    'FRE': ApplianceName('space heater', 1),
    'GRE': ApplianceName('misc', 3),
    'HPE': ApplianceName('air conditioner', 1),
    'HTE': ApplianceName('water heater', 1),
    'OFE': ApplianceName('misc', 4),
    'OUE': ApplianceName('plugs', 3),
    'TVE': ApplianceName('entertainment', 1),
    'UTE': ApplianceName('plugs', 4),
    'WOE': ApplianceName('oven', 1),
    'UNE': ApplianceName('unmetered', 1)
}

class DTW(Postprocessor):
	
	def __init__(self):
		super(DTW, self).__init__()
              
# Function to find event dominance ranking according to FHMM predictions
        def dominanceRanking (self, FHMMpredictions, nApp, diffPred, minPred):
            dom = []
            for i in range(nApp):
                if diffPred[i]<2:
                    dom.append(10000)
                else:
                    dom.append(np.subtract(np.percentile(FHMMpredictions[i], 95),minPred[i])) 
            domIndex = np.argsort(dom)[::-1]
            del dom, nApp
            return domIndex            
        
# Function to find the dominance of totConsumption and signatures using subsequence Dynamic Time Warping 
        def dominanceRankingTotal (self, currentEvent, nApp, domIndex,j, minPred, diffPred):
            dom = []
            for i in range(j,nApp): 
                currentApp = domIndex[i]
                signature = self.signatures.keys()[currentApp]

                initPath, dist = _ucrdtw.ucrdtw(self.signatures[signature], currentEvent, 0.1)
                path = range(initPath, initPath + len(currentEvent)) 
                signatureChunk = self.signatures.items()[currentApp][1][path]
                eventTemp=np.array(currentEvent)>=0
                signatureChunkTemp=signatureChunk[eventTemp]
                eventTemp=np.array(currentEvent)[eventTemp]
                if len(eventTemp)==0:
                    dist=np.sum(currentEvent)
                else:
                    if diffPred[currentApp]<2:
                        dist=0;
                    else:
                        signatureChunkTemp=np.subtract(signatureChunkTemp, minPred[currentApp])
                        dist=np.divide(np.percentile(np.abs(np.subtract(eventTemp, signatureChunkTemp)), 95), np.max(self.signatures.items()[currentApp][1])) # Scaled 95-th percentile distance on signature max value
                dom.append(dist)
            domIndexNew = np.argsort(dom)
            del dom, nApp
            toReturn=domIndex[domIndexNew[0]+j]
            return toReturn
        
         
# Function for performing DTW between total consumption and signatures
        def dtw_totalVsSig_singleEvent(self, event, signature):
           totDistances = list()
           totCosts = list()
           totPaths = list()
           currentEvent = event
           initPath, dist = _ucrdtw.ucrdtw(self.signatures[signature], currentEvent, 0.1)
           path = range(initPath, initPath + len(event)) 
           totDistances.append(dist)
           totPaths.append(path)
           self.totDistances[signature] = np.divide(totDistances, len(totPaths))
           self.totPaths[signature] = totPaths
           del totDistances, totPaths, currentEvent, path, initPath, dist
                     
# Function to perform corrections
        def correctPower_singleEvent(self, predictions, nApp, domIndex, totConsumption, posInit, posFin, event, eventlength, predCorr, minPred, maxPred, diffPred, meanPred):
                for i in range(nApp):
                    # print(event)
                    currentApp = domIndex[i]
                    minPredSum=[]
                    for k in range(i,len(domIndex)):#i+1
                        minPredSum.append(minPred[domIndex[k]])
                    minPredSum=np.sum(minPredSum)
                    if i<nApp-1:
                        event=np.subtract(event,minPredSum)
                    signature = self.signatures.keys()[currentApp]
                    self.dtw_totalVsSig_singleEvent(event, signature)
                    domIndexTotal=self.dominanceRankingTotal (event, nApp, domIndex, i, minPred, diffPred)
                                        
                    event=np.add(event, minPred[currentApp])
                    
                    if diffPred[currentApp]<2:
                    	# If appliances varies in a very small range, its prediction is set equal to its average value
                        newPredictions=np.multiply(np.ones(len(totConsumption[posInit:posFin + 1])), meanPred[currentApp])
                    else:
                        
                        # ::: FIRST CASE - TRUE POSITIVE detection
                        if  currentApp  == domIndexTotal:
                            positionSignature = self.totPaths[self.signatures.items()[currentApp][0]][0]
                            signatureChunk = self.signatures.items()[currentApp][1][positionSignature]
                            # Resize signature chunk
                            while len(signatureChunk) > eventlength:
                                toCut = randint(0, len(signatureChunk) - 1)
                                signatureChunk = np.delete(signatureChunk, toCut)
                            zerosEvent = np.multiply(np.ones(len(signatureChunk)), minPred[currentApp])
                            distZeros=np.sum(np.power(np.abs(np.subtract(event, zerosEvent)),1))
                            distSig=np.sum(np.power(np.abs(np.subtract(event, signatureChunk)),1))
                            distMarkov=np.sum(np.power(np.abs(np.subtract(event, predictions[currentApp][posInit:posFin + 1])),1))
                            
                            # Correction with zeros event - FALSE POSITIVE
                            if distZeros < distSig and distZeros < distMarkov:
                                newPredictions=zerosEvent
                            else:
                                # No correction on FHMM estimate
                                if distMarkov < distSig and np.max(np.abs(event-signatureChunk)) > np.max(np.abs(event-predictions[currentApp][posInit:posFin + 1])):
                                    newPredictions=predictions[currentApp][posInit:posFin + 1]
                                else:
                                    # Correction with signature
                                    boolPositions=signatureChunk > minPred[currentApp]
                                    positionsToCorrect = np.multiply(boolPositions, signatureChunk)
                                    positionsNotToCorrect = np.multiply(np.invert(boolPositions), predictions[currentApp][posInit:posFin + 1])
                                    newPredictions = positionsNotToCorrect + positionsToCorrect
                                    del positionSignature, signatureChunk, boolPositions, positionsToCorrect, positionsNotToCorrect
                        else:
                            
                            # ::: SECOND CASE - POSSIBLE FALSE POSITIVE detection: appliance is not dominating, but it was already on during the last 30 minutes (%%% length of interval to calibrate according to events length %%%)
                            zerosEvent = np.multiply(np.ones(len(predictions[currentApp][posInit-30:posInit])), minPred[currentApp])
                            zerosEvent2 = np.multiply(np.ones(len(predictions[currentApp][posInit-30:posInit])), minPred[domIndexTotal])
                            if  np.divide(np.sum(np.subtract(predictions[currentApp][posInit-30:posInit], zerosEvent)), np.max(predictions[currentApp])) >= np.divide(np.sum(np.subtract(predictions[domIndexTotal][posInit-30:posInit], zerosEvent2)), np.max(predictions[domIndexTotal])) :
                                positionSignature = self.totPaths[self.signatures.items()[currentApp][0]][0]
                                signatureChunk = self.signatures.items()[currentApp][1][positionSignature]
                                # Resize signature length
                                while len(signatureChunk) > eventlength:
                                    toCut = randint(0, len(signatureChunk) - 1)
                                    signatureChunk = np.delete(signatureChunk, toCut)
                                zerosEvent=np.multiply(np.ones(len(signatureChunk)), minPred[currentApp])
                                distZeros=np.sum(np.power(np.abs(np.subtract(event, zerosEvent)),1))
                                distSig=np.sum(np.power(np.abs(np.subtract(event, signatureChunk)),1))
                                distMarkov=np.sum(np.power(np.abs(np.subtract(event, predictions[currentApp][posInit:posFin + 1])),1))
                                # Correction with zeros event - FALSE POSITIVE
                                if distZeros < distSig and distZeros < distMarkov:
                                    newPredictions=zerosEvent
                                else:
                                    # No correction on FHMM estimate
                                    if distMarkov < distSig and np.percentile(np.abs(event-signatureChunk),95) > np.percentile(np.abs(event-predictions[currentApp][posInit:posFin + 1]),95):
                                        newPredictions=predictions[currentApp][posInit:posFin + 1]
                                    else:
                                        # Correction with signature
                                        boolPositions =signatureChunk > minPred[currentApp]
                                        positionsToCorrect = np.multiply(boolPositions, signatureChunk)
                                        positionsNotToCorrect = np.multiply(np.invert(boolPositions), predictions[currentApp][posInit:posFin + 1])
                                        newPredictions = positionsNotToCorrect + positionsToCorrect
                                        del positionSignature, signatureChunk, boolPositions, positionsToCorrect, positionsNotToCorrect
                            else:
                                
                                # ::: THIRD CASE - FALSE POSITIVE: appliance estimation needs to be switched off
                                boolPositions=predictions[currentApp][posInit:posFin+1]>0* np.max(predictions[currentApp])
                                minToCorrect=minPred[currentApp]
                                positionsToCorrect = np.multiply(boolPositions, minToCorrect)
                                positionsNotToCorrect = np.multiply(np.invert(boolPositions), predictions[currentApp][posInit:posFin + 1]) 
                                newPredictions = positionsNotToCorrect + positionsToCorrect
    
                    # Updating predictions and residual
                    newPredictions= np.minimum(newPredictions, event)
                    newPredictions [newPredictions < minPred[currentApp]] = minPred[currentApp]
                    predictions[currentApp][posInit:posFin + 1]=newPredictions
                    totConsumption[posInit:posFin + 1] = np.subtract(totConsumption[posInit:posFin + 1], predictions[currentApp][posInit:posFin + 1])
                    del event
                    zerosVector = np.multiply(np.ones(len(totConsumption[posInit:posFin + 1])), 0)
                    event = np.maximum(totConsumption.values[posInit:posFin + 1], zerosVector)
                    del newPredictions
                return predictions
                                               
# Function for loading signatures
	def load_signatures(self, root_directory):
			# Path to signatures
			signatures_folder = os.path.join(root_directory)
			# Listing files 
			list_of_files = glob.glob("%s*.txt" % signatures_folder)

			for txt_file in list_of_files:
				appliance_name = appliance_name_mapping[txt_file.split("/")[-1][:3]]
				self.signatures[appliance_name] = np.loadtxt(txt_file)
