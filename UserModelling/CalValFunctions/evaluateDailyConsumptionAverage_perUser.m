function dailyUserConsumptionVal = evaluateDailyConsumptionAverage_perUser(all_houses_Val, sH2O_meterID, nHH)

% dailyUserConsumptionVal = evaluateDailyConsumptionAveragePerUser(all_houses_Val, sH2O_meterID, nHH)
%
% Evaluates daily water consumption for each user in "all_houses_Val", for each day available in the data. 
% Results are then exported to .csv file.
%
% Copyright: The SmartH2O Consortium
% Last modified: Andrea Cominola, Apr 2017

minDate = nan;
maxDate = nan;

for i = 1:nHH
    % Get data of current house
    name = strcat('house_',sprintf('%03d',i));
    curr_house = all_houses_Val.(name);
    date = curr_house(:,1);
    cons = curr_house(:,2);
    day_of_week = curr_house(:,3);
    
    minDate = min(minDate, min(date));
    maxDate = max(maxDate, max(date));
end

dateVector = minDate:1:maxDate;
allAverages = nan(nHH, length(dateVector));

%numDaysPerUser =[1 numDaysPerUser];
allReadings=[];
allDates = [];
toRemove = [];

for i = 1:nHH
    % Get data of current house
    name = strcat('house_',sprintf('%03d',i));
    curr_house = all_houses_Val.(name);
    cons = curr_house(:,2);
    date = curr_house(:,1);
    day_of_week = curr_house(:,3);
    if isempty(curr_house) ==0 && length(unique(day_of_week))>=7 && sum(cons)>0
        
        % Average daily consuption
        temp1 = cumsum(cons);
        temp2 = temp1(24:24:end);
        tempDate = date(24:24:end);
        temp3 = diff(temp2);
        tempDate = datevec(tempDate);
        tempDate(:,4:end)=0;
        tempDate = datenum(tempDate);
        [~, datePositions] = ismember(tempDate, dateVector);
        allAverages(i,datePositions) = [temp2(1); temp3];
    else
        toRemove = [toRemove, i];
    end
end


dataToWrite1 = array2table(allAverages);
dataToWrite2 = table(sH2O_meterID);
dataToWrite = [dataToWrite2 dataToWrite1];

writetable(dataToWrite,'sH2O_Val_dailyWaterConsumptionAverage_singleUser.csv');
dailyUserConsumptionVal = dataToWrite;
end