function [classC, numClusters] = iterativeKmeans(LSArchive,thetaThreshold, minNumClusters, maxNumClustersAllowed)

% [classC, numClusters] = iterativeKmeans(LSArchive,thetaThreshold, minNumClusters, maxNumClustersAllowed)
%
% This function performs iterative kmeans clustering in agreement to Kwac
% et al., 2014.
%
% Copyright: The SmartH2O Consortium
% Last modified: Andrea Cominola, Apr 2017

% Initializing number of violations and while loop iteration
Nv=1;
iteration=1;
numClusters=minNumClusters;
newClustersC=[];
thresholdCondition=[];

while Nv>0
    if iteration==1
        % Finding centroids
        [classID, classC] = kmeans(LSArchive, numClusters,'EmptyAction','drop');
        clear classID
    end
    
    % Clustering the Load Shapes for given centroids
    classIDall  = kmeans(LSArchive,size(classC,1),'MaxIter',10,'Start',classC, 'EmptyAction','drop');
    
    for i=1:size(LSArchive,1)
        if isnan(classIDall(i))
            squaredE(i)=nan;
            thresholdCondition(i)=1;
        else
            squaredE(i) = sum((LSArchive(i,:) - classC(classIDall(i),:)).^2);
            thresholdCondition(i)=squaredE(i)>thetaThreshold*sum(classC(classIDall(i),:).^2);
        end
    end
    clear squaredE
    
    
    % Number of clusters violating the threshold condition
    Nv_temp=[];
    for i=1: numClusters
        Nv_temp(i)=sum(thresholdCondition(classIDall==i));
    end
    clear thresholdCondition
    
    Nv=sum(Nv_temp>0);
    
    if Nv==0
        break;
    elseif numClusters+Nv>maxNumClustersAllowed
        disp('ERROR: Failure to converge');
        break;
    else
        
        % Updating clusters number
        numClusters=numClusters+Nv;
        
        violatedClasses=find(Nv_temp>0);
        clear Nv_temp
        newClustersC=[]; % Clusters centroids to be added
        
        % Split each class where there are violations
        for violations=1:length(violatedClasses)
            
            % Separating the violating cluster in two subclusters
            [classIDtemp, classCtemp] = kmeans(LSArchive(classIDall==violatedClasses(violations),:), 2, 'EmptyAction','drop');
            newClustersC=[newClustersC;classCtemp];
            clear classCtemp
        end
    end
    idx=1:size(classC,1);
    toKeep=setdiff(idx,violatedClasses); % idx of representative Load Shapes to be kept
    reprLSkept=classC(toKeep,:);
    classC=[reprLSkept; newClustersC]; % Updated centroids
    clear newClustersC reprLSkept toKeep idx
end
