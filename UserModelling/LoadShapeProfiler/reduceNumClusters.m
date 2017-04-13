function [classCentroidsReduced, numClustersReduced] = reduceNumClusters(classCentroids,LSArchive, classIDall, corrThreshold)

% function [classCentroidsReduced, numClustersReduced] = reduceNumClusters(classCentroids,LSArchive, classIDall, corrThreshold)
%
% This function iteratively reduces the number of clusters in
% "classCentroids" up to meeting the condition of maximum correlation level
% among clusters as set by "corrThreshold"
%
% Copyright: The SmartH2O Consortium
% Last modified: Andrea Cominola, Apr 2017

classCentroidsReduced=classCentroids;
numClustersReduced=size(classCentroidsReduced,1);

classPosition1=[];
classPosition2=[];

% Correlation among cluster centroids
corrCoeff=corr(classCentroids');
corrCoeff(corrCoeff==1)=0;

while max(max(corrCoeff))>=corrThreshold
    %disp(numClustersReduced);
    [classPosition1, classPosition2]=find(corrCoeff==max(max(corrCoeff)));
    
    % Merging the two most correlated centroids
    newCentroid=(sum(classIDall==classPosition1(1)).*classCentroidsReduced(classPosition1(1),:)+sum(classIDall==classPosition2(1)).* classCentroidsReduced(classPosition2(1),:))./(sum(classIDall==classPosition1(1))+ sum(classIDall==classPosition2(1)));
    ind=[1:size(classCentroidsReduced,1)];
    toKeep=setdiff(ind,[classPosition1, classPosition2]);
    %disp(classPosition1);
    %disp(classPosition2);
    classCentroidsReduced=classCentroidsReduced(toKeep,:);
    classCentroidsReduced=[classCentroidsReduced;newCentroid];
    
    % Updating profiles
    classIDreduced  = kmeans(LSArchive,size(classCentroidsReduced,1),'MaxIter',10,'Start',classCentroidsReduced, 'EmptyAction', 'drop');
    numClustersReduced=size(classCentroidsReduced,1);
    corrCoeff=corr(classCentroidsReduced');
    corrCoeff(corrCoeff==1)=0;
end