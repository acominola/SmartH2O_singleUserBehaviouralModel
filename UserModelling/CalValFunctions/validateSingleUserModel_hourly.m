function [ecdfSim, ecdfData] = validateSingleUserModel_hourly(consumerFeatures,profilesProbabilitiesWD,profilesProbabilitiesWE, all_houses_Val)

% success = validateSingleUserModel_daily(consumerFeatures,profilesProbabilitiesWD,profilesProbabilitiesWE, all_houses_Val)
%
% Validated single user behavioural models by estimating hourly water consumption
% for single agents based on the results of the "hierarchicalClustering"
% function, and splitting the average daily water consumption into hourly water consumption
% according to the load shapes and their associated use probabilities.
% Finally, it visually compares the results with respect to the observed water
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
counter = 1;
for i =1:24:size(loadshape_wd,1)
    loadshape_wd(i:i+23,end-1) = counter;
    counter = counter+1;
end

tempToReshape = profilesProbabilitiesWE.probability_wrt_profile_label;
tempToReshape = reshape(tempToReshape, sqrt(length(tempToReshape)),sqrt(length(tempToReshape)));
tempToReshape = cumsum(tempToReshape);
tempToReshape = reshape(tempToReshape,size(tempToReshape,1)*size(tempToReshape,2),1 );
loadshape_we = [table2array(profilesProbabilitiesWE(:,4:end)), table2array(profilesProbabilitiesWE(:,2)), tempToReshape];
counter = 1;
for i =1:24:size(loadshape_we,1)
    loadshape_we(i:i+23,end-1) = counter;
    counter = counter+1;
end

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

% mean
MM{1,1} = mean(c11) ;
MM{2,1} = mean(c11) ;%c21) ;
MM{3,1} = mean(c11) ;%c31) ;
MM{4,1} = mean(c11) ;%c41) ;
MM{1,2} = mean(c15) ;
MM{2,2} = mean(c25) ;
MM{3,2} = mean(c35) ;
MM{4,2} = mean(c45) ;

% std
SS{1,1} = std(c11) ;
SS{2,1} = std(c11) ;%c11) ;%c21) ;
SS{3,1} = std(c11) ;%c31) ;
SS{4,1} = std(c11) ;%c41) ;
SS{1,2} = std(c15) ;
SS{2,2} = std(c25) ;
SS{3,2} = std(c35) ;
SS{4,2} = std(c45) ;


%% Organizing data for validation of daily consumption at household level
ccc = [];
nHHall = length(fieldnames(all_houses_Val));

%numDaysPerUser =[1 numDaysPerUser];
allProfiles_we=[];
allProfiles_wd=[];
toRemove = [];
allDayOfWeek = [];
allHourOfDay = [];
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
    hourTemp = datevec(date);
    hour_of_day = hourTemp(:,4);
    
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
        
        % Average hourly consuption
        temp1 = cumsum(cons);
        temp2 = diff(temp1);
        avg_hourly = [temp1(1); temp2];
        ccc = [ccc; avg_hourly] ;
        allDayOfWeek = [allDayOfWeek; day_of_week];
        allHourOfDay = [allHourOfDay; hour_of_day];
        
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


%% Generation of hourly consumption from pdf
T = round(maxDate - minDate);
nHHall = size(classes,1);

gCC = nan(nHHall,24,T);
dClass = classes(:,1:2);
dClass(dClass==5) = 2;
hClass = classes(:,3:4);
% simulation
countNeg =0;
for t=1:T
    dow(t) = mod(t-1,7)+1 ; % day of the week (1 = sun, 6 = fri, 7 = sat)
    if dow(t)<7 && dow(t) >1
        df = 1;
        loadshape = loadshape_wd;
    else
        df = 2;
        loadshape = loadshape_we;
    end
    for j=1:nHHall
        % daily consumption
        if isempty(SS{dClass(j,1),dClass(j,2)})
            gCC(j,:,t) = nan ;
            continue
        end
        dc = MM{dClass(j,1),dClass(j,2)}(df)+SS{dClass(j,1),dClass(j,2)}(df)*randn ;
        if dc<0
            dc=0;
            countNeg = countNeg +1;
        end
        % hourly disaggregation
        if isnan(hClass(j,df))
            gCC(j,:,t) = nan ;
            continue;
        end
        LPtemp = loadshape(loadshape(:,end-1)==hClass(j,df),:) ;
        if isempty(LPtemp)==0
            LP = LPtemp;
        end
        
        
        LP1 = [0; LP(:,end)];
        r = rand;
        clear LPid
        for k = 1:max(length(LP1)-1,1)
            if r>LP1(k) && r<LP1(k+1)
                LPid = k;
            else
                LPid =1;
            end
        end
        hc = dc.*LP(LPid,1:24) ;
        gCC(j,:,t) = hc ;
    end
end


%% Creating empirical CDFs of observed data and estimated data for visual comparison
% empirical CDF for different hour intervals

idxM = allHourOfDay > 4 & allHourOfDay <=9;
idxMD = allHourOfDay > 9 & allHourOfDay <=16;
idxE = allHourOfDay > 16 & allHourOfDay <=22;
idxN = allHourOfDay > 22 | allHourOfDay <=4;

cccM = ccc(logical(idxM));
cccMD = ccc(logical(idxMD));
cccE = ccc(logical(idxE));
cccN = ccc(logical(idxN));

idxRef = zeros(1,24);
idxMgen = idxRef; idxMgen(5:9) =1;
idxMDgen = idxRef; idxMDgen(10:16) =1;
idxEgen = idxRef; idxEgen(17:22) =1;
idxNgen = idxRef; idxNgen(1:4) =1;idxNgen(23:end) =1;

gCCM = gCC(:,logical(idxMgen),:);
gCCMD = gCC(:,logical(idxMDgen),:);
gCCE = gCC(:,logical(idxEgen),:);
gCCN = gCC(:,logical(idxNgen),:);


[f_2m,x_2m] = ecdf(cccM);
[f_sim2m,x_sim2m] = ecdf(gCCM(:));

[f_2md,x_2md] = ecdf(cccMD);
[f_sim2md,x_sim2md] = ecdf(gCCMD(:));

[f_2e,x_2e] = ecdf(cccE);
[f_sim2e,x_sim2e] = ecdf(gCCE(:));

[f_2n,x_2n] = ecdf(cccN);
[f_sim2n,x_sim2n] = ecdf(gCCN(:));

customizedFigureOpen;
subplot(221); % morning
plot( x_2m, f_2m, 'b', x_sim2m, f_sim2m, 'r' ,'LineWidth',2);
legend('Observed', 'Simulated') ; axis([0 0.8 0 1]);
xlabel('Hourly consumption (m^3/hour)'); ylabel('empirical CDF');
title('morning consumption 5.00-9.00');

subplot(222); % midday
plot( x_2md, f_2md, 'b', x_sim2md, f_sim2md, 'r' ,'LineWidth',2);
legend('Observed', 'Simulated') ; ylim([0 1]); axis([0 0.8 0 1]);
xlabel('Hourly consumption (m^3/hour)'); ylabel('empirical CDF');
title('midday consumption 10.00-16.00');

subplot(223); % evening
plot( x_2e, f_2e, 'b', x_sim2e, f_sim2e, 'r' ,'LineWidth',2);
legend('Observed', 'Simulated') ; ylim([0 1]); axis([0 0.8 0 1]);
xlabel('Hourly consumption (m^3/hour)'); ylabel('empirical CDF');
title('evening consumption 17.00-22.00');

subplot(224); % night
plot( x_2n, f_2n, 'b', x_sim2n, f_sim2n, 'r','LineWidth',2);
legend('Observed', 'Simulated') ; ylim([0 1]); axis([0 0.8 0 1]);
xlabel('Hourly consumption (m^3/hour)'); ylabel('empirical CDF');
title('night consumption 23.00-4.00');

% Simulated output statistics
ecdfSim.xM = x_sim2m; % morning
ecdfSim.fM = f_sim2m;
ecdfSim.xMD = x_sim2md; % midday
ecdfSim.fMD = f_sim2md;
ecdfSim.xE = x_sim2e; % evening
ecdfSim.fE = f_sim2e;
ecdfSim.xN = x_sim2n; % night
ecdfSim.fN = f_sim2n;

% Data output statistics
ecdfData.xM = x_sim2m; % morning
ecdfData.fM = f_sim2m;
ecdfData.xMD = x_sim2md; % midday
ecdfData.fMD = f_sim2md;
ecdfData.xE = x_sim2e; % evening
ecdfData.fE = f_sim2e;
ecdfData.xN = x_sim2n; % night
ecdfData.fN = f_sim2n;

end


