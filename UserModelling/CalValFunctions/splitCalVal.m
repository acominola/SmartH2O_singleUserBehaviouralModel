function [all_houses_Cal, all_houses_Val, meterID] = splitCalVal(all_houses, meterID, nHH, calibrationStart, calibrationEnd)

% [all_houses_Cal, all_houses_Val, meterID] = splitCalVal(all_houses, meterID, nHH, calibrationStart, calibrationEnd)
%
% Splits input dataset into calibration and validation dataset:
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
% "meterID" is a Matlab cell containing households smart meter ID. Each field
% is a char variable with the meter ID. The number of fields must be equal
% to nHH.
%
% "nHH" is an int variable representing the number of household data
% (field) in structure "all_houses"
%
% "calibrationStart" and "calibrationEnd" are Matlab date variables with
% the start and end dates of the period to consider for calibration.
%
% "all_houses_Cal" has the same structure of "all_houses" and contains data
% to be used for calibration.
%
% "all_houses_Val" has the same structure of "all_houses" and contains data
% to be used for validation.
%
% Copyright: The SmartH2O Consortium
% Last modified: Andrea Cominola, Apr 2017

names = fieldnames(all_houses);
counter = 0;
positionsToDelete=[];

for i=1:nHH
    nameCurr = names{i};
    temp = all_houses.(nameCurr);
    temp_cal = temp(temp(:,1) >= calibrationStart & temp(:,1) <= calibrationEnd,:);
    temp_val = temp(temp(:,1) > calibrationEnd,:);
    if isempty(temp_cal) || isempty(temp_val)
        positionsToDelete = [positionsToDelete, i]; 
        continue
    end
    counter = counter +1;
    nameCurr = strcat('house_',sprintf('%.3d',counter));
    all_houses_Cal.(nameCurr) = temp_cal;
    all_houses_Val.(nameCurr) = temp_val;
end

meterID(positionsToDelete)=[];



