function success = plotCommonLS(classCentroidsReduced, classIDallReduced)

% success = plotCommonLS(classCentroidsReduced, classIDallReduced)
%
% This function plots the most common Load Shapes, sorted by usage
% frequency.
%
% Copyright: The SmartH2O Consortium
% Last modified: Andrea Cominola, Apr 2017

% Frequency of adoption for each cluster
numClusters = size(classCentroidsReduced,1);
for j=1:numClusters
    frequencyC(j)= sum(classIDallReduced==j)/length(classIDallReduced);
end

[~, positionsC]=sort(frequencyC, 'descend');
cumFreq=0;

numPlotRow = round(sqrt(size(classCentroidsReduced,1))+0.5);
numPlotCol = round(sqrt(size(classCentroidsReduced,1)));

figure;
fontSize = 12;
set (gcf, 'DefaultTextFontName', 'Verdana', ...
    'DefaultTextFontSize', 8, ...
    'DefaultAxesFontName', 'Verdana', ...
    'DefaultAxesFontSize', 8, ...
    'DefaultLineMarkerSize', fontSize);
for i=1:size(classCentroidsReduced,1)
    h(i)=subplot(numPlotRow,numPlotCol,i);
    plot(classCentroidsReduced(positionsC(i),:));
    cumFreq=cumFreq+frequencyC(positionsC(i));
    titleName=(['freq:' num2str(frequencyC(positionsC(i))) ', cum freq:' num2str(cumFreq)]);
    %xlabel('Hour of day');
    ylabel('Load Shape');
    title(titleName);
    %axis([1 xAxisL 0 0.1]);
end
suptitle('Most common Load Shapes over the dataset');

success =1;