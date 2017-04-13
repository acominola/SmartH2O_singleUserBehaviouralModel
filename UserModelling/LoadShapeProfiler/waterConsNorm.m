function normalizedWaterCons = waterConsNorm(waterCons, hoursOfDay)

% function normalizedWaterCons = waterConsNorm(waterCons, hoursOfDay)
%
% This funcion normalizes the hourly water consumption over the total daily
% water consumption, for each day in the dataset.
%
% Copyright: The SmartH2O Consortium
% Last modified: Andrea Cominola, Apr 2017

dailyCons = sum(reshape(waterCons, hoursOfDay, length(waterCons)/hoursOfDay)); % Daily water consumption (aggregate of hourly for each day)
dailyConsReplicate = repmat(dailyCons,hoursOfDay,1);

dailyConshour24 = reshape(dailyConsReplicate,length(waterCons),1);
normalizedWaterCons = waterCons./dailyConshour24;   % Normalized hourly water consumption

end
