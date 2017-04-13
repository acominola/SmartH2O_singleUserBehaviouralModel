function binData = createHistBin_ABM(consumerFeatures)

% success = createHistBin_ABM(consumerFeatures)  
%
% Creates consumption histogram bins for SmartH2O agent-based model based on the results of the "hierarchicalClustering"
% function. Results are then exported to .csv file.
% By default, 10 histogram bins are created.
%
% Copyright: The SmartH2O Consortium
% Last modified: Andrea Cominola, Apr 2017

data = [consumerFeatures.Consumption_class, consumerFeatures.Day_label consumerFeatures.Profile_label_week consumerFeatures.Profile_label_weekend];
% col 1 consumption class (4 types)
% col 2 WE/WD
% col 3 daily consumption in weekdays
% col 4 daily consumption in weekends

tag_col_1=[1,5];
tag_col_3=[1,2,3,4];
hist_csv_week=[];
hist_csv_weekend=[];
header_week=[];
for j=1:length(tag_col_1)
    for k=1:length(tag_col_3)
        [binsd,centersd]=hist(data(data(:,2)==tag_col_1(j) & data(:,1)==tag_col_3(k),3),10);
        
        if sum(binsd)==0
            centersd=zeros(1,10);
            hist_csv_week=[hist_csv_week;[centersd-(centersd(2)-centersd(1))/2;centersd+(centersd(2)-centersd(1))/2];zeros(1,10)];
        else
            hist_csv_week=[hist_csv_week;[centersd-(centersd(2)-centersd(1))/2;centersd+(centersd(2)-centersd(1))/2];binsd/sum(binsd)];
        end
        header_week=[header_week; [1,tag_col_1(j),tag_col_3(k)]; [1,tag_col_1(j),tag_col_3(k)]; [1,tag_col_1(j),tag_col_3(k)]];
        
    end
end
hist_csv_week=[header_week,hist_csv_week];
header_weekend=[];
for j=1:length(tag_col_1)
    for k=1:length(tag_col_3)
        [binsd,centersd]=hist(data(data(:,2)==tag_col_1(j) & data(:,1)==tag_col_3(k),4),10);
        if sum(binsd)==0
            centersd=zeros(1,10);
            hist_csv_weekend=[hist_csv_weekend;[centersd-(centersd(2)-centersd(1))/2;centersd+(centersd(2)-centersd(1))/2];zeros(1,10)];
        else
            hist_csv_weekend=[hist_csv_weekend;[centersd-(centersd(2)-centersd(1))/2;centersd+(centersd(2)-centersd(1))/2];binsd/sum(binsd)];
        end
        header_weekend=[header_weekend; [2,tag_col_1(j),tag_col_3(k)]; [2,tag_col_1(j),tag_col_3(k)]; [2,tag_col_1(j),tag_col_3(k)]];
    end
end
hist_csv_weekend=[header_weekend,hist_csv_weekend];
hist_csv=vertcat(hist_csv_week);
hist_csv=vertcat(hist_csv,hist_csv_weekend);
filename = 'sH2O_Cal_histogramBin_ABM.csv';

dataToWrite = array2table(hist_csv,  ...
    'VariableNames',{'weekend_label','Day_label','Consumption_class','b1','b2','b3','b4','b5','b6','b7','b8','b9','b10'});
writetable(dataToWrite,filename);

binData = dataToWrite;
end
