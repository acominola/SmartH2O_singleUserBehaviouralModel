function [ecdfSim, ecdfData] = validateSingleUserModel_daily(consumerFeatures,profilesProbabilitiesWD,profilesProbabilitiesWE, all_houses_Val)

% success = validateSingleUserModel_daily(consumerFeatures,profilesProbabilitiesWD,profilesProbabilitiesWE, all_houses_Val)
%
% Validated single user behavioural models by estimating daily water consumption
% for single agents based on the results of the "hierarchicalClustering"
% function, and visually compares the results with respect to the observed water
% consumption.
%
% Copyright: The SmartH2O Consortium
% Last modified: Andrea Cominola, Apr 2017

% Reorganizing output from hierarchical clustering
dailyCons = [consumerFeatures.Average_consumption, consumerFeatures.Avg_consumption_week, consumerFeatures.Avg_consumption_weekend];
classes = [consumerFeatures.Consumption_class, consumerFeatures.Day_label,consumerFeatures.Profile_label_week,consumerFeatures.Profile_label_weekend];

tempToReshape = profilesProbabilitiesWD.probability_wrt_profile_label;
tempToReshape = reshape(tempToReshape, sqrt(length(tempToReshape)),sqrt(length(tempToReshape)));
tempToReshape = cumsum(tempToReshape);
tempToReshape = reshape(tempToReshape,size(tempToReshape,1)*size(tempToReshape,2),1 );
loadshape_wd = [table2array(profilesProbabilitiesWD(:,4:end)), table2array(profilesProbabilitiesWD(:,2)), tempToReshape];

tempToReshape = profilesProbabilitiesWE.probability_wrt_profile_label;
tempToReshape = reshape(tempToReshape, sqrt(length(tempToReshape)),sqrt(length(tempToReshape)));
tempToReshape = cumsum(tempToReshape);
tempToReshape = reshape(tempToReshape,size(tempToReshape,1)*size(tempToReshape,2),1 );
loadshape_we = [table2array(profilesProbabilitiesWE(:,4:end)), table2array(profilesProbabilitiesWE(:,2)), tempToReshape];


%% Users profiling - daily

% Average consumption classe
idC1 = classes(:,1) == 1 ;
idC2 = classes(:,1) == 2 ;
idC3 = classes(:,1) == 3 ;
idC4 = classes(:,1) == 4 ;

% Highest consumption day-label
idD1 = classes(:,2)==1 ;
idD5 = classes(:,2)==5 ;

% Creating possible profiles
idx11 = idC1.*idD1; idx15 = idC1.*idD5;
idx21 = idC2.*idD1; idx25 = idC2.*idD5;
idx31 = idC3.*idD1; idx35 = idC3.*idD5;
idx41 = idC4.*idD1; idx45 = idC4.*idD5;
N11 = sum(idx11); N15 = sum(idx15) ;
N21 = sum(idx21); N25 = sum(idx25) ;
N31 = sum(idx31); N35 = sum(idx35) ;
N41 = sum(idx41); N45 = sum(idx45) ;

% pdf for each profile (weekday, weekend)
c11 = [dailyCons(logical(idx11),2), dailyCons(logical(idx11),3)] ;
c21 = [dailyCons(logical(idx21),2), dailyCons(logical(idx21),3)] ;
c31 = [dailyCons(logical(idx31),2), dailyCons(logical(idx31),3)] ;
c41 = [dailyCons(logical(idx41),2), dailyCons(logical(idx41),3)] ;
c15 = [dailyCons(logical(idx15),2), dailyCons(logical(idx15),3)] ;
c25 = [dailyCons(logical(idx25),2), dailyCons(logical(idx25),3)] ;
c35 = [dailyCons(logical(idx35),2), dailyCons(logical(idx35),3)] ;
c45 = [dailyCons(logical(idx45),2), dailyCons(logical(idx45),3)] ;
m11 = mean(c11) ; s11 = std(c11) ;
m21 = mean(c21) ; s21 = std(c21) ;
m31 = mean(c31) ; s31 = std(c31) ;
m41 = mean(c41) ; s41 = std(c41) ;
m15 = mean(c15) ; s15 = std(c15) ;
m25 = mean(c25) ; s25 = std(c25) ;
m35 = mean(c35) ; s35 = std(c35) ;
m45 = mean(c45) ; s45 = std(c45) ;

%% Organizing data for validation of daily consumption at household level
ccc = [];
nHHall = length(fieldnames(all_houses_Val));

%numDaysPerUser =[1 numDaysPerUser];
allProfiles_we=[];
allProfiles_wd=[];
toRemove = [];
allDayOfWeek = [];
numDays = [];
minDate = nan;
maxDate = nan;

for i = 1:nHHall

    % get data of current house
    name = strcat('house_',sprintf('%03d',i));
    curr_house = all_houses_Val.(name);
    date = curr_house(:,1);
    cons = curr_house(:,2);
    day_of_week = curr_house(:,3);
    
    minDate = min(minDate, min(date));
    maxDate = max(maxDate, max(date));
    
    if isempty(curr_house) ==0
        % Selecting only calibration data
        
        dateVal = date;
        diffDateVal = dateVal(end) - dateVal(1);
        clear lengthVal
        lengthVal = round(length(dateVal)/24);
    else
        toRemove = [toRemove, i];
        continue;
    end
    
    if isempty(curr_house) ==0 && length(unique(day_of_week))>=7 && diffDateVal >= 15 && sum(cons)>0
        
        % Average daily consuption
        temp1 = cumsum(cons);
        temp2 = temp1(24:24:end);
        temp3 = diff(temp2);
        avg_daily = [temp2(1); temp3];
        ndays = length(avg_daily) ;
        obsCons{i} = avg_daily ;
        ccc = [ccc; avg_daily] ;
        numDays = [numDays; length(avg_daily)];
        day_of_week_temp = day_of_week(1:24:lengthVal*24);
        allDayOfWeek = [allDayOfWeek; day_of_week_temp];
    else
        toRemove = [toRemove, i];
    end
end


%% Generation of daily consumption from pdf
T = round(maxDate - minDate);

% initialization
genCons11 = nan(T,N11) ;
genCons21 = nan(T,N21) ;
genCons31 = nan(T,N31) ;
genCons41 = nan(T,N41) ;
genCons15 = nan(T,N15) ;
genCons25 = nan(T,N25) ;
genCons35 = nan(T,N35) ;
genCons45 = nan(T,N45) ;

%% Simulating water consumption for the defined horizon
for t=1:T
    dow(t) = mod(t-1,7)+1 ; % day of the week (1 = sun, 6 = fri, 7 = sat)
    if dow(t)<7 && dow(t) >1
        df = 1;
    else
        df = 2;
    end
    % daily consumption
    genCons11(t,:) = m11(df)+s11(df)*randn(1,N11) ;
    genCons21(t,:) = m21(df)+s21(df)*randn(1,N21) ;
    genCons31(t,:) = m31(df)+s31(df)*randn(1,N31) ;
    genCons41(t,:) = m41(df)+s41(df)*randn(1,N41) ;
    genCons15(t,:) = m15(df)+s15(df)*randn(1,N15) ;
    genCons25(t,:) = m25(df)+s25(df)*randn(1,N25) ;
    genCons35(t,:) = m35(df)+s35(df)*randn(1,N35) ;
    genCons45(t,:) = m45(df)+s45(df)*randn(1,N45) ;
end
gCC = [genCons11 genCons21 genCons31 genCons41 ...
    genCons15 genCons25 genCons35 genCons45 ...
    ] ;
gCC(gCC<0) = 0;


%% Creating empirical CDFs of observed data and estimated data for visual comparison
[f_2,x_2] = ecdf(ccc) ;
[f_sim2,x_sim2] = ecdf(gCC(:));

customizedFigureOpen; 
plot( x_2, f_2, 'b', x_sim2, f_sim2, 'r','LineWidth',2);
legend('Observed', 'Simulated') ; axis([0 max(max(gCC(:)), max(max(ccc))) 0 1]);
xlabel('Daily consumption (m^3/day)'); ylabel('empirical CDF')

% Empirical CDF for different day type (weekend and weekdays)

idxWD = allDayOfWeek > 1 & allDayOfWeek <7;
idxWE = allDayOfWeek == 1 | allDayOfWeek == 7;

idxWDgen = dow > 1 & dow <7;
idxWEgen = dow == 1 | dow == 7;

cccWD = ccc(logical(idxWD));
gCCWD = gCC(logical(idxWDgen),:);
cccWE = ccc(logical(idxWE));
gCCWE = gCC(logical(idxWEgen),:);


[f_2wd,x_2wd] = ecdf(cccWD) ;
[f_sim2wd,x_sim2wd] = ecdf(gCCWD(:));

[f_2we,x_2we] = ecdf(cccWE) ;
[f_sim2we,x_sim2we] = ecdf(gCCWE(:));


customizedFigureOpen;

subplot(121); % weekdays
plot( x_2wd, f_2wd, 'b', x_sim2wd, f_sim2wd, 'r','LineWidth',2);
legend('Observed', 'Simulated') ; axis([0 max(max(gCCWD(:)), max(max(cccWD))) 0 1]);
xlabel('Daily consumption (m^3/day)'); ylabel('empirical CDF');
title('Only weekdays');

subplot(122); % weekends
plot( x_2we, f_2we, 'b', x_sim2we, f_sim2we, 'r','LineWidth',2);
legend('Observed', 'Simulated') ; axis([0 max(max(gCCWE(:)), max(max(cccWE))) 0 1]);
xlabel('Daily consumption (m^3/day)'); ylabel('empirical CDF');
title('Only weekends');

% Simulated output statistics
ecdfSim.x = x_sim2;
ecdfSim.f = f_sim2;
ecdfSim.xWE = x_sim2we;
ecdfSim.xWD = x_sim2wd;
ecdfSim.fWE = x_sim2we;
ecdfSim.fWD = x_sim2wd;

% Data output statistics
ecdfData.x = x_2;
ecdfData.f = f_2;
ecdfData.xWE = x_2we;
ecdfData.xWD = x_2wd;
ecdfData.fWE = x_2we;
ecdfData.fWD = x_2wd;



end


