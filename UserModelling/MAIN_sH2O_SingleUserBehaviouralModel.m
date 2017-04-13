% This is the MAIN file of the SmartH2O single-user behavioural model
%
% Copyright: The SmartH2O Consortium
% Last modified: Andrea Cominola, Apr 2017


% --- Loading data and settings

% Setting folder path
currentDir = pwd;
addpath(genpath([currentDir '/LoadShapeProfiler']));
addpath(genpath([currentDir '/CalValFunctions']));

% Loading Matlab file with hourly water consumption data for each
% household. The file must be a Matlab structure, each field being an N-by-3
% matrix with data for a single household, where N is the number of
% monitored day for the considered household and the 3 columns are, respectively: 
% 1 - date number
% 2 - water consumption [m^3/hour]
% 3 - integer ID {1:7} representing the day of the week: 1 is Sunday, 7 is
% Saturday.
% Each field is named "house_nnn", where nnn represents the progressive
% number of household starting from 001.
load all_houses.mat

% Evaluating the number of households in the database
nHH = length(fieldnames(all_houses)); 

% Loading the Matlab cell containing households smart meter ID. Each field
% is a char variable with the meter ID. The number of fields must be equal
% to nHH.
load meterID.mat
%%
% --- Splitting data for training and testing

% Setting start and ending date for the training (calibration) period. All data after
% the "calibrationEnd" date are going to be considered as test (validation)
% data.
calibrationStart = datenum('1-6-2015 00:00');
calibrationEnd = datenum('1-31-2016 23:59');

[all_houses_Cal, all_houses_Val, meterID] = splitCalVal(all_houses, meterID, nHH, calibrationStart, calibrationEnd);
nHH = length(fieldnames(all_houses_Cal)); % Updating available number of households in the training and test dataset (values with no 
                                          % data for the calibration or validation period have been removed.

%% --- Evaluating daily water consumption Load Shapes

% Setting parameters for load shape extraction
LSparam.minNumClusters = 3; % Minimum number of Load Shapes allowed
LSparam.maxNumClusters = 3*nHH; % Maximum number of Load Shapes allowed

LSparam.thetaThreshold = 0.2; % Theta threshold for squared centroid distance error
LSparam.corrThreshold = 0.5; % Correlation coefficient threshold for cluster merging

[classCentroidsReduced, classIDallReduced] = LSevaluator(all_houses_Cal, nHH, LSparam);
plotCommonLS(classCentroidsReduced, classIDallReduced); % Plot most common load shapes

%% --- Single-user behavioural model TRAINING
[consumerFeatures, meterID,profilesProbabilitiesWD,profilesProbabilitiesWE] = hierarchicalClustering(all_houses_Cal, meterID, nHH, classCentroidsReduced, classIDallReduced);
nHH = length(meterID); % Updating available number of households 

%% --- Single-user behavioural model TESTING
[ecdfSimDaily, ecdfDataDaily] = validateSingleUserModel_daily(consumerFeatures,profilesProbabilitiesWD,profilesProbabilitiesWE, all_houses_Val);
[ecdfSimHourly, ecdfDataHourly] = validateSingleUserModel_hourly(consumerFeatures,profilesProbabilitiesWD,profilesProbabilitiesWE, all_houses_Val);

%% --- Exporting output for Agent-based model
consumptionBinData = createHistBin_ABM(consumerFeatures);
dailyUserConsumptionVal = evaluateDailyConsumptionAverage_perUser(all_houses_Val, meterID, nHH);
dailyAggregateConsumptionVal = evaluateDailyConsumptionAverage_aggregate(all_houses_Val, meterID, nHH);