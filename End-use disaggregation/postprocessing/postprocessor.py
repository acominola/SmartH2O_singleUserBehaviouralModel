# Importing useful libraries
from nilmtk.dataset import ampds
from nilmtk.disaggregate.fhmm_exact import FHMM
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

class Postprocessor(object):
	
	def __init__(self):
		self.signatures={}
		self.totDistances={}
		self.totPaths={}
		self.appDistances={}
		self.appPaths={}