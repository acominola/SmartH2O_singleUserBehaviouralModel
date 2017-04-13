function dailyAggregateConsumptionVal = evaluateDailyConsumptionAverage_aggregate(all_houses_Val, sH2O_meterID, nHH)

% dailyUserConsumptionVal = evaluateDailyConsumptionAveragePerUser(all_houses_Val, sH2O_meterID, nHH)
%
% Evaluates daily aggregate water consumption across all users available in "all_houses_Val", for each day available in the data.
% Results are then exported to .csv file.
%
% Copyright: The SmartH2O Consortium
% Last modified: Andrea Cominola, Apr 2017

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
        
        % average daily consuption
        temp1 = cumsum(cons);
        temp2 = temp1(24:24:end);
        tempDate = date(24:24:end);
        temp3 = diff(temp2);
        allDates = [allDates; tempDate];
        allReadings = [allReadings; [temp2(1); temp3]];
    else
        toRemove = [toRemove, i];
    end
end

availableDays = unique(allDates);

for i =1:length(availableDays)
    tempReadings = allReadings(allDates == availableDays(i));
    allUserAverage(i) = mean(tempReadings);
    numUsersPerDay(i) = length(tempReadings);
    clear tempReadings;
end

[~, idx] = sort(availableDays, 'Ascend');
allUserAverage = allUserAverage(idx);
numUsersPerDay = numUsersPerDay(idx);
dateVector = datevec(availableDays');
dataToWrite = table(dateVector(:,1), dateVector(:,2), dateVector(:,3),allUserAverage', numUsersPerDay',...
    'VariableNames',{'Year' 'Month' 'Day' 'AverageAggregateConsumption' 'NumUsers'});
writetable(dataToWrite,'sH2O_Val_dailyWaterConsumptionAverage_aggregate.csv');
dailyAggregateConsumptionVal = dataToWrite;

end