function LSArchiveUpdated = addToArchive(LSArchive, normalizedWaterCons, numDayHour)

% LSArchiveUpdated = addToArchive(LSArchive, normalizedWaterCons, numDayHour);
%
% This function populates the archive of potential load shapes.
%
% Copyright: The SmartH2O Consortium
% Last modified: Andrea Cominola, Apr 2017

LSArchiveUpdated = [LSArchive; reshape(normalizedWaterCons,numDayHour,length(normalizedWaterCons)/numDayHour)'];
LSArchiveUpdated(isnan(LSArchiveUpdated))=0;

end

