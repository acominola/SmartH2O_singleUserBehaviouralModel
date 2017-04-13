function [consumerFeatures, meterID,profilesProbabilitiesWD, profilesProbabilitiesWE] = hierarchicalClustering(all_houses_Cal, meterID, nHH, classCentroidsReduced, classIDallReduced)

% consumerFeatures = hierarchicalClustering(all_houses_Cal, meterID, nHH, classCentroidsReduced, classIDallReduced)
% 
% Performs hierarchical clustering as described in deliverable D3.4 of the
% SmartH2O project, on the following features: 
%
% 1. Average daily water consumption
% 2. Average daily water consumption during weekdays
% 3. Average daily water consumption during weekends
% 4. Most used load shape
% 5. Type of day with highest consumption
%
% Copyright: The SmartH2O Consortium
% Last modified: Andrea Cominola, Apr 2017

allProfiles_we=[];
allProfiles_wd=[];
toRemove = [];
allDayOfWeek = [];
avg_daily = [];
numDaysPerUser = zeros(1,nHH);

% Selecting only complete days
for i=1:nHH % looping through all houses
    name = strcat('house_',sprintf('%.3d',i));
    curr_house = all_houses_Cal.(name);
    date_vec = datevec(curr_house(:,1));
    hour = date_vec(:,4);
    n = numel(hour);
    startID(i) = find(hour==0,1);
    hour_inverted = hour(end:-1:1);
    endID(i) = n - find(hour_inverted==23,1) +1;
    curr_house = curr_house(startID(i):endID(i),:);
    all_houses_Cal.(name) = curr_house;
end

%% Evaluating features for hierarchical clustering.

for i = 1:nHH % Looping through houses

    % Get data of current house
    name = strcat('house_',sprintf('%03d',i));
    curr_house = all_houses_Cal.(name);
    date = curr_house(:,1);
    
    cons = curr_house(:,2);
    day_of_week = curr_house(:,3);
    date = date(:);
    
    diffDateCal = date(end) - date(1);
    
    if isempty(curr_house) ==0 && length(unique(day_of_week))>=7 && diffDateCal >= 15 && sum(cons)>0
        % Checking that the current house:
        % (i) is not empty;
        % (ii) has data for at least 7 different days;
        % (iii) has calibration data for at least 15 days;
        % (iv) has not zero consumption.
        
        % Average daily consuption
        temp1 = cumsum(cons);
        temp2 = temp1(24:24:end);
        temp3 = diff(temp2);
        avg_daily(i-length(toRemove)) = mean([temp2(1); temp3]);
        
        % Average daily consumption in weekends
        clear temp1 temp2 temp3
        temp1 = cumsum(cons(day_of_week == 1 | day_of_week == 7));
        temp2 = temp1(24:24:end);
        temp3 = diff(temp2);
        avg_dailyWE(i-length(toRemove)) = mean([temp2(1); temp3]);
        
        % Average daily consumption in weekdays
        clear temp1 temp2 temp3
        temp1 = cumsum(cons(day_of_week == 2 | day_of_week == 3 | day_of_week == 4 | day_of_week == 5 | day_of_week == 6));
        temp2 = temp1(24:24:end);
        temp3 = diff(temp2);
        avg_dailyWD(i-length(toRemove)) = mean([temp2(1); temp3]);
        
        numDaysPerUser(i) = length(date)/24;
        
        % Most used load shape
        if i==1
            tempLS = classIDallReduced(1:numDaysPerUser(1));
        else
            tempLS = classIDallReduced(sum(numDaysPerUser(1:i-1))+1:sum(numDaysPerUser(1:i)));
        end
        
        clear countTemp_we countTemp_wd
        day_of_week_temp = day_of_week(1:24:end);
        tempLS_wd = tempLS(day_of_week_temp == 2 | day_of_week_temp == 3 | day_of_week_temp == 4 | day_of_week_temp == 5 | day_of_week_temp == 6);
        tempLS_we = tempLS(day_of_week_temp == 1 | day_of_week_temp == 7);
        
        allProfiles_we=[allProfiles_we; tempLS_we];
        allProfiles_wd=[allProfiles_wd; tempLS_wd];
        allDayOfWeek = [allDayOfWeek; day_of_week_temp];
        
        for j = 1:size(classCentroidsReduced,1)
            countTemp_we(j) = sum(tempLS_we == j);
            countTemp_wd(j) = sum(tempLS_wd == j);
        end
        
        [~, selectedL_we] = max(countTemp_we);
        [~, selectedL_wd] = max(countTemp_wd);
        
        LSmostUsed_we(i-length(toRemove)) = selectedL_we;
        LSmostUsed_wd(i-length(toRemove)) = selectedL_wd;
        
    else
        toRemove = [toRemove, i];
    end
end
meterID(toRemove) = [];

% Binary feature WD/WE
higherDay = ones(1,length(meterID));
higherDay(avg_dailyWE > avg_dailyWD) =5;

%% Performing kmeans clustering (k=4) on average daily consumption to evaluate consumption cluster ID.
[idx, centroids]=kmeans(avg_daily',4, 'MaxIter',5000);
[~, sortedPos] = sort(centroids, 'Ascend');

idx = idx';
idxTemp = idx;
for i=1:length(centroids)
    idxTemp(idx == sortedPos(i)) = i;
end
idx = idxTemp; % Consumption cluster ID.


% Saving table with features hierarchical clustering output (needed as
% input for the SmartH2O agent-based model).
dataToWrite = table(meterID,avg_daily',higherDay',idx',avg_dailyWD', avg_dailyWE',LSmostUsed_wd', LSmostUsed_we',  ...
    'VariableNames',{'Meter_ID' 'Average_consumption' 'Day_label' 'Consumption_class' 'Avg_consumption_week' 'Avg_consumption_weekend' ...
    'Profile_label_week' 'Profile_label_weekend'});
writetable(dataToWrite,'sH2O_Cal_clusteringAndProfiling.csv');
consumerFeatures = dataToWrite;

%% Create vector for comparison of main profiles and sub-profiles
LSmostUsed_wd_rep=[];
LSmostUsed_we_rep=[];
i = 0;

for j = 1:nHH
    
    name = strcat('house_',sprintf('%03d',j));
    curr_house = all_houses_Cal.(name);
    date = curr_house(:,1);
    cons = curr_house(:,2);
    
    diffDateCal = date(end) - date(1);
    if isempty(curr_house) ==0 && length(unique(day_of_week))>=7 && diffDateCal >= 15 && sum(cons)>0
        i=i+1;
        if i==1
            dayIDtemp = allDayOfWeek(1:numDaysPerUser(1));
        else
            dayIDtemp = allDayOfWeek(sum(numDaysPerUser(1:i-1))+1:sum(numDaysPerUser(1:i)));
        end
        
        numWDdays = sum(dayIDtemp == 2 | dayIDtemp == 3 | dayIDtemp == 4 | dayIDtemp == 5 | dayIDtemp == 6);
        numWEdays = sum(dayIDtemp == 1 | dayIDtemp == 7);
        
        tempWE = ones(numWEdays,1);
        tempWE = tempWE.*LSmostUsed_we(i);
        
        tempWD = ones(numWDdays,1);
        tempWD = tempWD.*LSmostUsed_wd(i);
        
        LSmostUsed_wd_rep = [LSmostUsed_wd_rep; tempWD];
        LSmostUsed_we_rep = [LSmostUsed_we_rep; tempWE];
        clear tempWE tempWD
    else
        continue;
    end
end

% Evaluating probabilities
for i =1:size(classCentroidsReduced,1)
    tempAccounts_wd = LSmostUsed_wd_rep == i;
    tempAccounts_we = LSmostUsed_we_rep == i;
    
    tempProfiles_wd = allProfiles_wd(tempAccounts_wd);
    tempProfiles_we = allProfiles_we(tempAccounts_we);
    
    for j =1:size(classCentroidsReduced,1)
        profileFreq_wd(i,j) = sum(tempProfiles_wd==j)./length(tempProfiles_wd);
        profileFreq_we(i,j) = sum(tempProfiles_we==j)./length(tempProfiles_we);
    end
end
profileFreq_wd(isnan(profileFreq_wd))=0;
profileFreq_we(isnan(profileFreq_we))=0;

tempVector =[1:size(classCentroidsReduced,1)];
tempMatrix = repmat(tempVector,size(classCentroidsReduced,1),1);
profileLabel = reshape(tempMatrix,size(tempMatrix,1)*size(tempMatrix,2),1);
subprofile = repmat(tempVector',size(classCentroidsReduced,1),1);

probabilities_WE = reshape(profileFreq_we',size(profileFreq_we,1)*size(profileFreq_we,2),1);
probabilities_WD = reshape(profileFreq_wd',size(profileFreq_wd,1)*size(profileFreq_wd,2),1);

sortedProfiles = repmat(classCentroidsReduced,size(classCentroidsReduced,1),1);

% Saving tables with probabilities of Load Shape usage for weekends and
% week days (needed as input for the SmartH2O agent-based model).
dataToWriteWE = table(profileLabel,subprofile,probabilities_WE, sortedProfiles(:,1),sortedProfiles(:,2),sortedProfiles(:,3),sortedProfiles(:,4),...
    sortedProfiles(:,5),sortedProfiles(:,6),sortedProfiles(:,7),sortedProfiles(:,8),sortedProfiles(:,9),sortedProfiles(:,10),sortedProfiles(:,11),...
    sortedProfiles(:,12),sortedProfiles(:,13),sortedProfiles(:,14),sortedProfiles(:,15),sortedProfiles(:,16),sortedProfiles(:,17),sortedProfiles(:,18),sortedProfiles(:,19),...
    sortedProfiles(:,20),sortedProfiles(:,21),sortedProfiles(:,22),sortedProfiles(:,23),sortedProfiles(:,24),...
    'VariableNames',{'Profile_label' 'sub_profile' 'probability_wrt_profile_label' 'h0' 'h1' 'h2' 'h3' 'h4' 'h5' 'h6' 'h7' 'h8' 'h9' 'h10' 'h11' 'h12' ...
    'h13' 'h14' 'h15' 'h16' 'h17' 'h18' 'h19' 'h20' 'h21' 'h22' 'h23'});

dataToWriteWD = table(profileLabel,subprofile,probabilities_WD, sortedProfiles(:,1),sortedProfiles(:,2),sortedProfiles(:,3),sortedProfiles(:,4),...
    sortedProfiles(:,5),sortedProfiles(:,6),sortedProfiles(:,7),sortedProfiles(:,8),sortedProfiles(:,9),sortedProfiles(:,10),sortedProfiles(:,11),...
    sortedProfiles(:,12),sortedProfiles(:,13),sortedProfiles(:,14),sortedProfiles(:,15),sortedProfiles(:,16),sortedProfiles(:,17),sortedProfiles(:,18),sortedProfiles(:,19),...
    sortedProfiles(:,20),sortedProfiles(:,21),sortedProfiles(:,22),sortedProfiles(:,23),sortedProfiles(:,24),...
    'VariableNames',{'Profile_label' 'sub_profile' 'probability_wrt_profile_label' 'h0' 'h1' 'h2' 'h3' 'h4' 'h5' 'h6' 'h7' 'h8' 'h9' 'h10' 'h11' 'h12' ...
    'h13' 'h14' 'h15' 'h16' 'h17' 'h18' 'h19' 'h20' 'h21' 'h22' 'h23'});

writetable(dataToWriteWE,'sH2O_Cal_profilesProbabilities_WE.csv');
writetable(dataToWriteWD,'sH2O_Cal_profilesProbabilities_WD.csv');
profilesProbabilitiesWD = dataToWriteWD;
profilesProbabilitiesWE = dataToWriteWE;

end
