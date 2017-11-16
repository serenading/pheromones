clear
close all

%%% to consider: plot perimeterNorm/areaNorm by strain with error bars...
%%% (normalised file by file so each movie is a separate replicate to provide variation), ...
%%% rather than pooling everything together across movies and plot a single line for each strain
%%% - currently not working properly with overlaid shadedErrorBars

%%% phase-restrict movies to joining phase only

exportOptions = struct('Format','eps2',...
    'Color','rgb',...
    'Width',15,...
    'Resolution',300,...
    'FontMode','fixed',...
    'FontSize',15,...
    'LineWidth',3);

%% set parameters
strains = {'npr1','daf22_npr1','N2','daf22',}; % {'N2','npr1','daf22','daf22_npr1'}
numSampleSkel = 500; % number of skeletons (per file) to sample in order to determine overall skeleton lengths for normalisation
areaCutOff = 5; % 5 seems good
perimeterCutOff = 2.5; % 2.5 seems good
saveResults = true;

%% initialise
swLengthFig = figure; hold on
swWidthFig = figure; hold on
swPerimeterFig = figure; hold on
swAreaFig = figure; hold on
perimeterFig = figure; hold on
areaFig = figure; hold on
perimeterThresholdFig = figure;
areaThresholdFig = figure;

%% go through strains, densities, movies
for strainCtr = 1:length(strains)
    strain = strains{strainCtr};
    legendList{strainCtr} = strain;
    filenames = importdata(['datalist/' strain '_list.txt']);
    
    %% initialise
    numFiles = length(filenames);
    perimeter.(strains{strainCtr}) = cell(numFiles,1);
    area.(strains{strainCtr}) = cell(numFiles,1);
    perimeterNorm.(strains{strainCtr}) = cell(numFiles,1);
    areaNorm.(strains{strainCtr}) = cell(numFiles,1);
    
    perimeterBinEdges = [1:0.1:4];
    areaBinEdges = [1:1/3:9];
    perimeterHistCount.(strains{strainCtr}) = NaN(numFiles,numel(perimeterBinEdges)-1);
    areaHistCount.(strains{strainCtr}) = NaN(numFiles,numel(areaBinEdges)-1);
    
    perimeterThres.(strains{strainCtr}) = NaN(1,numFiles);
    areaThres.(strains{strainCtr}) = NaN(1,numFiles);

    swLengths.(strains{strainCtr}) =  NaN(numFiles,numSampleSkel); 
    swWidths.(strains{strainCtr}) = NaN(numFiles,numSampleSkel);
    swPerimeters.(strains{strainCtr}) = NaN(numFiles,numSampleSkel);
    swAreas.(strains{strainCtr}) = NaN(numFiles,numSampleSkel);
    


    %% go through individual movies
    for fileCtr = 1:numFiles
        
        %% load data
        filename = filenames{fileCtr};
        trajData = h5read(filename,'/trajectories_data');
        blobFeats = h5read(filename,'/blob_features');
        skelData = h5read(filename,'/skeleton');
        frameRate = double(h5readatt(filename,'/plate_worms','expected_fps'));
        
        %% obtain features, filtering out single worms
        multiWormLogInd = logical(~trajData.is_good_skel);
        perimeter.(strains{strainCtr}){fileCtr} = blobFeats.perimeter(multiWormLogInd);
        area.(strains{strainCtr}){fileCtr} = blobFeats.area(multiWormLogInd);
        
        %% calculate worm skeleton length (as daf-22 containing animals appear smaller) to normalise features against later
        % load xy coordinates
        xcoords = squeeze(skelData(1,:,:));
        ycoords = squeeze(skelData(2,:,:));
        % filter for single worms
        singleWormLogInd = logical(trajData.is_good_skel);
        xcoords = xcoords(:,singleWormLogInd);
        ycoords = ycoords(:,singleWormLogInd);
        singleWormArea = blobFeats.area(singleWormLogInd);
        singleWormPerimeter = blobFeats.perimeter(singleWormLogInd);
        % extract single worm features and calculate skeleton length
        [~,sampleSkelIdx] = datasample(1:size(xcoords,2),numSampleSkel,'Replace',false); % sample 500 random single worm skeletons
        xcoords = xcoords(:,sampleSkelIdx);
        ycoords = ycoords(:,sampleSkelIdx); 
        singleWormArea = singleWormArea(sampleSkelIdx);
        singleWormPerimeter = singleWormPerimeter(sampleSkelIdx);
        for skelCtr = 1:numSampleSkel
            skel_xcoords = xcoords(:,skelCtr);
            skel_ycoords = ycoords(:,skelCtr);
            dx = skel_xcoords(2:end)-skel_xcoords(1:end-1);
            dy = skel_ycoords(2:end)-skel_ycoords(1:end-1);
            dz = sqrt(dx.^2 + dy.^2);
            swLengths.(strains{strainCtr})(fileCtr,skelCtr) = sum(dz);
            swAreas.(strains{strainCtr})(fileCtr,skelCtr) = singleWormArea(skelCtr);
            swPerimeters.(strains{strainCtr})(fileCtr,skelCtr) = singleWormPerimeter(skelCtr);
            swWidths.(strains{strainCtr})(fileCtr,skelCtr) = swAreas.(strains{strainCtr})(fileCtr,skelCtr)...
                /swLengths.(strains{strainCtr})(fileCtr,skelCtr);
        end
        
        %% plot histogram of normalised area and perimeter, taking each movie as a replicate
        % normalise area and perimeter from this movie with sw features from this movie; store value for threshold box plot later
        perimeterNorm.(strains{strainCtr}){fileCtr} = perimeter.(strains{strainCtr}){fileCtr}/median(swPerimeters.(strains{strainCtr})(fileCtr,:));
        areaNorm.(strains{strainCtr}){fileCtr} = area.(strains{strainCtr}){fileCtr}/median(swAreas.(strains{strainCtr})(fileCtr,:));
        % remove low values below 1 as clusters should by definition be larger than single worms thus min normalised value should be 1
        perimeterNorm.(strains{strainCtr}){fileCtr} =  perimeterNorm.(strains{strainCtr}){fileCtr}( perimeterNorm.(strains{strainCtr}){fileCtr}>1);
        areaNorm.(strains{strainCtr}){fileCtr} = areaNorm.(strains{strainCtr}){fileCtr}(areaNorm.(strains{strainCtr}){fileCtr}>1);
        % generate histogram bin count
        [perimeterHistCount.(strains{strainCtr})(fileCtr,:),~] = histcounts(perimeterNorm.(strains{strainCtr}){fileCtr},perimeterBinEdges);
        [areaHistCount.(strains{strainCtr})(fileCtr,:),~] = histcounts(areaNorm.(strains{strainCtr}){fileCtr},areaBinEdges);

        %% calculate probability above the threshold cut-off, taking each movie as a replicate
        perimeterThres.(strains{strainCtr})(fileCtr) = numel(find(perimeterNorm.(strains{strainCtr}){fileCtr}>perimeterCutOff))/numel(perimeterNorm.(strains{strainCtr}){fileCtr});
        areaThres.(strains{strainCtr})(fileCtr) = numel(find(areaNorm.(strains{strainCtr}){fileCtr}>areaCutOff))/numel(areaNorm.(strains{strainCtr}){fileCtr});
        
    end
 
    %% pool data across movies (one way of plotting overall distribution without variation across replicates)
    swLength = median(swLengths.(strains{strainCtr})(:));
    swWidth = median(swWidths.(strains{strainCtr})(:));
    swArea = median(swAreas.(strains{strainCtr})(:));
    swPerimeter = median(swPerimeters.(strains{strainCtr})(:));
    perimeter.(strains{strainCtr}) = vertcat(perimeter.(strains{strainCtr}){:});
    area.(strains{strainCtr}) = vertcat(area.(strains{strainCtr}){:});
    
   %% use worm skeleton lengths to normalise blob features
    perimeter.(strains{strainCtr}) = perimeter.(strains{strainCtr})/swPerimeter;
    area.(strains{strainCtr}) = area.(strains{strainCtr})/swArea;
    perimeter.(strains{strainCtr})= perimeter.(strains{strainCtr})(perimeter.(strains{strainCtr})>1);
    area.(strains{strainCtr}) = area.(strains{strainCtr})(area.(strains{strainCtr})>1);

    %% plot figures (pooled across movies)
    set(0,'CurrentFigure',swLengthFig)
    histogram(swLengths.(strains{strainCtr}),'Normalization','pdf','DisplayStyle','stairs')
    set(0,'CurrentFigure',swWidthFig)
    histogram(swWidths.(strains{strainCtr}),'Normalization','pdf','DisplayStyle','stairs')
    set(0,'CurrentFigure',swAreaFig)
    histogram(swAreas.(strains{strainCtr}),'Normalization','pdf','DisplayStyle','stairs')
    set(0,'CurrentFigure',swPerimeterFig)
    histogram(swPerimeters.(strains{strainCtr}),'Normalization','pdf','DisplayStyle','stairs')
    
    set(0,'CurrentFigure',perimeterFig)
    histogram(perimeter.(strains{strainCtr}),'Normalization','pdf','DisplayStyle','stairs')
    set(0,'CurrentFigure',areaFig)
    histogram(area.(strains{strainCtr}),'Normalization','pdf','DisplayStyle','stairs')
end

%% plot probability above threshold (per movie replicate)
% generate group series for box plots
boxplotGroup = [ones(size(perimeterThres.(strains{1}))) 2*ones(size(perimeterThres.(strains{2}))) 3*ones(size(perimeterThres.(strains{3}))) 4*ones(size(perimeterThres.(strains{4})))];
% perimeter
set(0,'CurrentFigure',perimeterThresholdFig)
boxplot([perimeterThres.(strains{1}),perimeterThres.(strains{2}),perimeterThres.(strains{3}),perimeterThres.(strains{4})],boxplotGroup,'notch','on','labels',legendList);
title('perimeter')
ylabel('probability')
set(perimeterThresholdFig,'PaperUnits','centimeters')
figurename = ['figures/perimeterThreshold_' num2str(perimeterCutOff)];
if saveResults
    exportfig(perimeterThresholdFig,[figurename '.eps'],exportOptions)
    system(['epstopdf ' figurename '.eps']);
    system(['rm ' figurename '.eps']);
end
% area
set(0,'CurrentFigure',areaThresholdFig)
boxplot([areaThres.(strains{1}),areaThres.(strains{2}),areaThres.(strains{3}),areaThres.(strains{4})],boxplotGroup,'notch','on','labels',legendList);
title('area')
ylabel('probability')
set(areaThresholdFig,'PaperUnits','centimeters')
figurename = ['figures/areaThreshold_' num2str(areaCutOff)];
if saveResults
    exportfig(areaThresholdFig,[figurename '.eps'],exportOptions)
    system(['epstopdf ' figurename '.eps']);
    system(['rm ' figurename '.eps']);
end

    
%% change legend format for the double mutant strain for subsequent plots
if strcmp(legendList{2},'daf22_npr1')
    legendList{2} = 'daf22\_npr1'; % add back slash so n doesn't become subscript
else
    warning('need to rename daf22_npr1 to avoid subscript appearance in legend')
end

%% plot distribution (per movie replicate)
% generate x axis series 
perimeter_x = (1:size(perimeterHistCount.(strains{strainCtr}),2))/(size(perimeterHistCount.(strains{strainCtr}),2)/perimeterBinEdges(end));
area_x = (1:size(areaHistCount.(strains{strainCtr}),2))/(size(areaHistCount.(strains{strainCtr}),2)/areaBinEdges(end));
% perimeter
figure; hold on
pH(1) = shadedErrorBar(perimeter_x,perimeterHistCount.(strains{1}),{@mean,@std},'lineprops','-b','transparent',1);
pH(2) = shadedErrorBar(perimeter_x,perimeterHistCount.(strains{2}),{@mean,@std},'lineprops','-r','transparent',1);
pH(3) = shadedErrorBar(perimeter_x,perimeterHistCount.(strains{3}),{@mean,@std},'lineprops','-g','transparent',1);
pH(4) = shadedErrorBar(perimeter_x,perimeterHistCount.(strains{4}),{@mean,@std},'lineprops','-k','transparent',1);
legend([pH(1).mainLine, pH(2).mainLine,pH(3).mainLine,pH(4).mainLine],strains{1},strains{2},strains{3},strains{4})
% area
figure; hold on
aH(1) = shadedErrorBar(area_x,areaHistCount.(strains{1}),{@mean,@std},'lineprops','-b','transparent',1);
aH(2) = shadedErrorBar(area_x,areaHistCount.(strains{2}),{@mean,@std},'lineprops','-r','transparent',1);
aH(3) = shadedErrorBar(area_x,areaHistCount.(strains{3}),{@mean,@std},'lineprops','-g','transparent',1);
aH(4) = shadedErrorBar(area_x,areaHistCount.(strains{4}),{@mean,@std},'lineprops','-k','transparent',1);
legend([aH(1).mainLine, aH(2).mainLine,aH(3).mainLine,aH(4).mainLine],strains{1},strains{2},strains{3},strains{4})

%% format distribution plots (pooled across movies)
% perimeter
set(0,'CurrentFigure',perimeterFig)
legend(legendList)
xlabel('perimeter')
ylabel('probability')
xlim([1 10])
figurename = 'figures/perimeter';
if saveResults
    exportfig(perimeterFig,[figurename '.eps'],exportOptions)
    system(['epstopdf ' figurename '.eps']);
    system(['rm ' figurename '.eps']);
end
% area
set(0,'CurrentFigure',areaFig)
legend(legendList)
xlabel('area')
ylabel('probability')
xlim([1 20])
figurename = 'figures/area';
if saveResults
    exportfig(areaFig,[figurename '.eps'],exportOptions)
    system(['epstopdf ' figurename '.eps']);
    system(['rm ' figurename '.eps']);
end

%% format single worm feature plots (pooled across movies)
% length
set(0,'CurrentFigure',swLengthFig)
legend(legendList)
xlabel('single worm length')
ylabel('probability')
set(swLengthFig,'PaperUnits','centimeters')
figurename = 'figures/swLength';
if saveResults
    exportfig(swLengthFig,[figurename '.eps'],exportOptions)
    system(['epstopdf ' figurename '.eps']);
    system(['rm ' figurename '.eps']);
end
% "width"
set(0,'CurrentFigure',swWidthFig)
legend(legendList)
xlabel('single worm width')
ylabel('probability')
set(swWidthFig,'PaperUnits','centimeters')
figurename = 'figures/swWidth';
if saveResults
    exportfig(swWidthFig,[figurename '.eps'],exportOptions)
    system(['epstopdf ' figurename '.eps']);
    system(['rm ' figurename '.eps']);
end
% area
set(0,'CurrentFigure',swAreaFig)
legend(legendList)
xlabel('single worm area')
ylabel('probability')
set(swAreaFig,'PaperUnits','centimeters')
figurename = 'figures/swArea';
if saveResults
    exportfig(swWidthFig,[figurename '.eps'],exportOptions)
    system(['epstopdf ' figurename '.eps']);
    system(['rm ' figurename '.eps']);
end
% perimeter
set(0,'CurrentFigure',swPerimeterFig)
legend(legendList)
xlabel('single worm perimeter')
ylabel('probability')
set(swPerimeterFig,'PaperUnits','centimeters')
figurename = 'figures/swPerimeter';
if saveResults
    exportfig(swPerimeterFig,[figurename '.eps'],exportOptions)
    system(['epstopdf ' figurename '.eps']);
    system(['rm ' figurename '.eps']);
end
