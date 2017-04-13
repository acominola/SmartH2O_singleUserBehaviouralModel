function [classCentroidsReduced, classIDallReduced] = LSevaluator(all_houses, nHH, LSparam)

% function [classCentroidsReduced, classIDallReduced] = LSevaluator(all_houses, nHH, LSparam)
%
% "all_houses" must be a Matlab structure, each field being an N-by-3
% matrix with data for a single household, where N is the number of
% monitored day for the considered household and the 3 columns are, respectively:
% 1 - date number
% 2 - water consumption [m^3/hour]
% 3 - integer ID {1:7} representing the day of the week: 1 is Sunday, 7 is
% Saturday.
% Each field is named "house_nnn", where nnn represents the progressive
% number of household starting from 001.
%
% "nHH" is an int variable representing the number of household data
% (field) in structure "all_houses"
%
% "LSparam" is a Matlab structure containing the following fields:
% LSparam.minNumClusters: minimum number of Load Shapes allowed
% LSparam.maxNumClusters: maximum number of Load Shapes allowed
% LSparam.thetaThreshold: Theta threshold for squared centroid distance error
% LSparam.corrThreshold: correlation coefficient threshold for cluster merging

% The function evaluates daily Load Shapes of hourly water consumption
% data, adapting iterative k-means clustering and the methodology explained in:
% Kwac, Jungsuk, June Flora, and Ram Rajagopal. "Household energy consumption segmentation using hourly data."
% IEEE Transactions on Smart Grid 5.1 (2014): 420-430.
%
% Copyright: The SmartH2O Consortium
% Last modified: Andrea Cominola, Apr 2017

% Settings
numDayHour=24; % number of hours per day
numWeekDays=7; % number of days per week
minNumClusters=LSparam.minNumClusters; % minimum number of clusters
maxNumClustersAllowed=LSparam.maxNumClusters; % maximum number of clusters allowed
thetaThreshold=LSparam.thetaThreshold; % Maximum threshold allowed for squared centroid distance error.
corrThreshold=LSparam.corrThreshold; % Maximum centroid correlation allowed

startID = zeros(nHH,1);    % Starting line of the data series to consider
endID = zeros(nHH,1);      % Ending line of the data series to consider

houses = fieldnames(all_houses);

% Selecting only complete days
for i=1:nHH % looping through all houses
    name = strcat('house_',sprintf('%.3d',i));
    curr_house = all_houses.(name);
    date_vec = datevec(curr_house(:,1));
    hour = date_vec(:,4);
    n = numel(hour);
    startID(i) = find(hour==0,1);
    hour_inverted = hour(end:-1:1);
    endID(i) = n - find(hour_inverted==23,1) +1;
    curr_house = curr_house(startID(i):endID(i),:);
    all_houses.(name) = curr_house;
end

% LOAD SHAPE ARCHIVE CONSTRUCTION
%
%
% Evaluating normalized consumption (normalized on the cumulative daily value)
LSArchive=[]; % Allocating space for the load shape profiles archive

for j=1:nHH % looping through all houses
    
    % Selecting specific house from the database
    name=strcat('all_houses.', houses(j));
    name=name{1,1};
    selHH=eval(name);
    
    waterCons{1,j}=selHH(:,2);     % Hourly water consumption
    dayOfWeek{1,j}=selHH(:,3);     % Day of the week index
    
    hourOfDay{1,j}=datevec(selHH(:,1));
    hourOfDay{1,j}=hourOfDay{1,j}(:,4);  % hour of day {1,24}
    
    % Checking data length for hoursOfDay hours normalization
    if rem(length(waterCons{1,j}),numDayHour)~=0
        disp('ERROR: check size of consumption vector');
    end
    
    % Normalizing consumption for each day
    normalizedWaterCons{1,j} = waterConsNorm(waterCons{1,j}, numDayHour);
    
    % Populating profiles archive
    LSArchive = addToArchive( LSArchive, normalizedWaterCons{1,j}, numDayHour);
end

maxNumClusters = length(LSArchive); % Theoretical maximum number of clusters

%% ITERATIVE KMEANS CLUSTERING
%
% Idea ottimizzare

% Initializing number of clusters
maxNumClustersAllowed=maxNumClustersAllowed; % maxNumClusters

% Running iterative kmeans number of clusters
[classCentroids, numClusters] = iterativeKmeans(LSArchive,thetaThreshold, minNumClusters, maxNumClustersAllowed);

% Classifying the Load Shapes according to the defined centroids
classCentroids=classCentroids(isnan(sum(classCentroids'))==0,:);
numClusters=size(classCentroids,1);
classIDall  = kmeans(LSArchive,numClusters,'MaxIter',10,'Start',classCentroids,'EmptyAction','drop');

%% Cluster number reduction

% Evaluating a reduced number of centroids based on correlation
[classCentroidsReduced, numClustersReduced] = reduceNumClusters(classCentroids, LSArchive, classIDall, corrThreshold);

% Classifying the Load Shapes according to the newly defined centroids
classCentroidsReduced=classCentroidsReduced(isnan(sum(classCentroidsReduced'))==0,:);
numClustersReduced=size(classCentroidsReduced,1);
classIDallReduced  = kmeans(LSArchive,numClustersReduced,'MaxIter',10,'Start',classCentroidsReduced,'EmptyAction','drop');

disp('Total number of Load Shapes found:');
disp(numClustersReduced);

end

