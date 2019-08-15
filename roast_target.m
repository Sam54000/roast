function roast_target(subj,simTag,targetCoord,varargin)

fprintf('\n\n');
disp('=============================================================')
disp('ROAST is an aggregated work by Yu (Andy) Huang licensed under')
disp('General Public License version 3 or later. It''s supported by')
disp('both NIH grants and Soterix Medical Inc.')
disp('=============================================================')

addpath(genpath([fileparts(which(mfilename)) filesep 'lib/']));

fprintf('\n\n');
disp('======================================================')
disp('CHECKING INPUTS...')
disp('======================================================')
fprintf('\n');

% warning('on');
warning('off','MATLAB:nargchk:deprecated');

% check subject name
if nargin<1 || isempty(subj)
    subj = 'example/MNI152_T1_1mm.nii';
end

if strcmpi(subj,'nyhead')
    subj = 'example/nyhead.nii';
end

% if ~strcmpi(subj,'example/nyhead.nii') && ~exist(subj,'file')
%     error(['The subject MRI you provided ' subj ' does not exist.']);
% end

% check simulation tag
if nargin<2 || isempty(simTag)
    error(['Please provide a valid simulation tag for Subject ' subj ', so that roast_target() can locate the corresponding lead field.']);
end

[dirname,baseFilename,ext] = fileparts(subj);
if ~exist([dirname filesep baseFilename '_' simTag '_options.mat'],'file')
    error(['Option file not found. Simulation ' simTag ' may never be run. Please run it first.']);
else
    load([dirname filesep baseFilename '_' simTag '_options.mat'],'opt');
end

if ~strcmp(opt.configTxt,'leadFieldGeneration')
    error(['Simulation ' simTag ' was NOT run for generating the lead field for subject ' subj '. roast_target() cannot work without a proper lead field. Please run ROAST with ''leadField'' as the recipe first.']);
end

% to locate related files (e.g. MRI header, *_seg8 mapping, tissue masks)
if opt.resamp
    subjRS = [dirname filesep baseFilename '_1mm' ext];
else
    subjRS = subj;
end

if opt.zeroPad>0
    [dirname2,baseFilename2,ext2] = fileparts(subjRS);
    subjRSPD = [dirname2 filesep baseFilename2 '_padded' num2str(opt.zeroPad) ext2];
    %     subjRSPD = ['example/nyhead_padded' num2str(paddingAmt) '.nii'];
else
    subjRSPD = subjRS;
end

[~,baseFilenameRSPD] = fileparts(subjRSPD);
hdrFile = [dirname filesep baseFilenameRSPD '_header.mat'];
if ~exist(hdrFile,'file')
    error(['Header file ' hdrFile ' not found. Check if you run through electrode placement in ROAST.']);
else
    load(hdrFile,'hdrInfo');
end

% check target coordinates
if nargin<3 || isempty(targetCoord)
    targetCoord = [-48 -8 50]; % defaults to left primary motor cortex
end

if size(targetCoord,2) ~= 3
    error('Unrecognized format of target coordinates. Please enter as [x y z].');
end

% take in user-specified options
if mod(length(varargin),2)~=0
    error('Unrecognized format of options. Please enter as property-value pair.');
end

indArg = 1;
while indArg <= length(varargin)
    switch lower(varargin{indArg})
        case 'coordtype'
            coordType = varargin{indArg+1};
            indArg = indArg+2;
        case 'opttype'
            optType = varargin{indArg+1};
            indArg = indArg+2;
        case 'orient'
            orient = varargin{indArg+1};
            indArg = indArg+2;
        case 'elecnum'
            elecNum = varargin{indArg+1};
            indArg = indArg+2;
        case 'targetradius'
            targetRadius = varargin{indArg+1};
            indArg = indArg+2;
        case 'k'
            k = varargin{indArg+1};
            indArg = indArg+2;
        case 'a'
            a = varargin{indArg+1};
            indArg = indArg+2;        
        otherwise
            error('Supported options are: ''coordType'', ''optType'', ''orient'', ''elecNum'', ''targetRadius'', ''k'' and ''a''.');
    end
end

% set up defaults and check on option conflicts
if ~exist('coordType','var')
    coordType = 'mni';
else
    if ~any(strcmpi(coordType,{'mni','voxel'}))
        error('Please enter either ''mni'' or ''voxel'' for option ''coordType''.');
    end
end

if strcmpi(coordType,'voxel') && (any(mod(targetCoord(:),1)~=0) || ...
        any(targetCoord(:)<=0) || any(targetCoord(:,1)>hdrInfo.dim(1)) || ...
        any(targetCoord(:,2)>hdrInfo.dim(2)) || any(targetCoord(:,3)>hdrInfo.dim(3)))
    error('Voxel coordinates should be entered as positive integers, and should not go beyond image boundary.');
end
numOfTargets = size(targetCoord,1);

if ~exist('optType','var')
    optType = 'max-l1';
else
    if ~any(strcmpi(optType,{'unconstrained-wls','wls-l1','wls-l1per','wls-l1penalty','unconstrained-lcmv','lcmv-l1','lcmv-l1per','max-l1','max-l1per'}))
        error('Supported targeting optimizations are: ''unconstrained-wls'',''wls-l1'',''wls-l1per'',''wls-l1penalty'',''unconstrained-lcmv'',''lcmv-l1'',''lcmv-l1per'',''max-l1'' and ''max-l1per''.');
    end
end

if ~exist('orient','var')
    orient = cell(numOfTargets,1);
    for i=1:numOfTargets, orient{i} = 'radial-in'; end
else
    if ~iscell(orient)
        if ischar(orient)
            if ~ismember(lower(orient),{'radial-in','radial-out','right','left','anterior','posterior','right-anterior','right-posterior','left-anterior','left-posterior','optimal'})
                error('Supported orientations of electric field at the target are: ''radial-in'',''radial-out'',''right'',''left'',''anterior'',''posterior'',''right-anterior'',''right-posterior'',''left-anterior'',''left-posterior'',''optimal''.');
            end
            orient0 = orient;
            orient = cell(numOfTargets,1);
            for i=1:numOfTargets, orient{i} = orient0; end
        else
            if size(orient,2)~=3
                error('Unrecognized customized orientation. Please enter the customized orientation vector for each target as a 1-by-3 vector.');
            end
            if size(orient,1)>1 && size(orient,1)~=numOfTargets
                error('You want different customized orientations at each target. Please tell roast_target() the customized orientation for each target respectively, in a N-by-3 matrix, where N is the number of targets.');
            end
            if size(orient,1)==1 && numOfTargets>1
                orient = repmat(orient,numOfTargets,1);
            end
        end
    else
        if length(orient)~=numOfTargets
            error('You want different orientations at each target. Please tell roast_target() the orientation for each target respectively, in a N-by-1 cell, where N is the number of targets.');
        end
        nOptimal = 0;
        for i=1:numOfTargets
            if ischar(orient{i})
                if ~ismember(lower(orient{i}),{'radial-in','radial-out','right','left','anterior','posterior','right-anterior','right-posterior','left-anterior','left-posterior','optimal'})
                    error('Supported orientations of electric field at the target are: ''radial-in'',''radial-out'',''right'',''left'',''anterior'',''posterior'',''right-anterior'',''right-posterior'',''left-anterior'',''left-posterior'',''optimal''.');
                end
                if strcmpi(orient{i},'optimal'), nOptimal = nOptimal + 1; end
            else
                if size(orient{i},2)~=3
                    error('Unrecognized customized orientation. Please enter the customized orientation vector for each target as a 1-by-3 vector.');
                end
                if size(orient{i},1)>1
                    error('You want different customized orientations at each target. Please tell roast_target() the customized orientation in a 1-by-3 vector.');
                end
            end
        end
        if nOptimal>0 && nOptimal~=numOfTargets
            error('roast_target() cannot perform targeting for mixed optimal and unoptimal orientations. Please specify either all-optimal or all-unoptimal orientations for all the targets.');
        end
    end
end

needOrigin = 0;
if iscell(orient)
    for i=1:numOfTargets
        if ischar(orient{i}) && ismember(lower(orient{i}),{'radial-in','radial-out','optimal'})
            needOrigin = 1;
        end
        break;
    end
end

if ~exist('elecNum','var')
    if strcmpi(optType,'max-l1per')
        elecNum = 4;
    else
        elecNum = [];
    end
else
    if strcmpi(optType,'max-l1per')
        if elecNum<4 || mod(elecNum,2)~=0
            error('Unrecognized option value. Please enter positive even number of at least 4 for option ''elecNum''.');
        end
    else
        warning('Option ''elecNum'' will be ignored for optimization type other than ''max-l1per''.');
        elecNum = [];
    end
end

if ~exist('targetRadius','var')
    targetRadius = 3;
else
    if targetRadius<=0 || mod(targetRadius,1)~=0
        error('Unrecognized option value. Please enter positive integer value for option ''targetRadius''.');
    end
end

if ~exist('k','var')
    if ~isempty(strfind(lower(optType),'wls'))
        k = 0.8;
    else
        k = [];
    end
else
    if ~isempty(strfind(lower(optType),'wls'))
        if k<=0 || k>=1
            error('Unrecognized option value. Please enter the ''k'' value between 0 and 1.');
        else
            warning('You''re changing the advanced options of ROAST-TARGET. Unless you know what you''re doing, please keep the ''k'' value default.');
        end
    else
        warning('Option ''k'' will be ignored for optimization type other than weighted least square.');
        k = [];
    end
end

if ~exist('a','var')
    if strcmpi(optType,'lcmv-l1') || strcmpi(optType,'lcmv-l1per')
        a = 0.5;
    else
        a = 1;
    end
else
    if strcmpi(optType,'lcmv-l1') || strcmpi(optType,'lcmv-l1per')
        if a<=0 || a>=1
            error('Unrecognized option value. Please enter the ''a'' value between 0 and 1.');
        else
            warning('You''re changing the advanced options of ROAST-TARGET. Unless you know what you''re doing, please keep the ''a'' value default.');
        end
    else
        warning('Option ''a'' will be ignored for optimization type other than the constrained LCMV.');
        a = 1;
    end    
end

% to locate related files (e.g. MRI header, *_seg8 mapping, tissue masks)
if isempty(opt.T2)
    baseFilenameRSPD = [baseFilenameRSPD '_T1orT2'];
else
    baseFilenameRSPD = [baseFilenameRSPD '_T1andT2'];
end

if strcmpi(coordType,'mni') || needOrigin
    mappingFile = [dirname filesep baseFilenameRSPD '_seg8.mat'];
    if ~exist(mappingFile,'file')
        error(['Mapping file ' mappingFile ' from SPM not found. Please check if you run through SPM segmentation in ROAST.']);
    else
        load(mappingFile,'image','Affine');
        mni2mri = inv(image(1).mat)*inv(Affine);
        % mapping from MNI space to individual MRI
    end
end

if strcmpi(coordType,'mni')
    for i=1:numOfTargets
        temp = mni2mri*[targetCoord(i,:) 1]';
        targetCoord(i,:) = round(temp(1:3)');
    end
end
if any(targetCoord(:)<=0) || any(targetCoord(:,1)>hdrInfo.dim(1)) || ...
        any(targetCoord(:,2)>hdrInfo.dim(2)) || any(targetCoord(:,3)>hdrInfo.dim(3))
    error('Unrecognized target coordinates. Please check if you entered voxel coordinates but specified MNI coordinates, or the other way around.');
end

if needOrigin
    temp = mni2mri*[0 0 0 1]';
    origin = round(temp(1:3)');
end

% prepare data
p.numOfTargets = numOfTargets;
p.I_max = 2; % 2 mA
p.targetCoord = targetCoord;
p.optType = lower(optType);
p.elecNum = elecNum;
p.targetRadius = targetRadius;
p.k = k;
p.a = a;

if ~iscell(orient)
    u0 = orient;
else
    u0 = zeros(numOfTargets,3);
    for i=1:numOfTargets
        if ischar(orient{i})
            switch lower(orient{i})
                case {'radial-in','optimal'}
                    u0(i,:) = origin-targetCoord(i,:);
                case 'radial-out'
                    u0(i,:) = targetCoord(i,:)-origin;
                case 'right'
                    u0(i,:) = [1 0 0];
                case 'left'
                    u0(i,:) = [-1 0 0];
                case 'anterior'
                    u0(i,:) = [0 1 0];
                case 'posterior'
                    u0(i,:) = [0 -1 0];
                case 'right-anterior'
                    u0(i,:) = [1 1 0];
                case 'right-posterior'
                    u0(i,:) = [1 -1 0];
                case 'left-anterior'
                    u0(i,:) = [-1 1 0];
                case 'left-posterior'
                    u0(i,:) = [-1 -1 0];
            end
        else
            u0(i,:) = orient{i};
        end
    end
end

for i=1:size(u0,1)
    u0(i,:) = u0(i,:)/norm(u0(i,:)); % unit vector
    if any(isnan(u0(i,:)))
        error(['Orientation vector at target ' num2str(i) ' has a length close to 0. It could be that you picked a target too close to the brain center.']);
    end
end
p.u = u0;

if ~exist([dirname filesep baseFilename '_' simTag '_result.mat'],'file')
    error(['Lead field not found for subject ' subj ' under simulation tag ' simTag '. Please check if you ran ROAST with ''leadField'' as the recipe first.']);
else
    disp('Loading the lead field for targeting...');
    load([dirname filesep baseFilename '_' simTag '_result.mat'],'A','locs');
end
Nnodes = size(locs,1);  % number of mesh nodes
p.Nnodes = Nnodes;

% start targeting code
p = optimize_prepare(p,A,locs);

if ismember('optimal',lower(orient))
    u = zeros(numOfTargets,3);
    t0 = zeros(numOfTargets,2);
    for i=1:numOfTargets
        [t0(i,1),t0(i,2)] = cart2sph(u0(i,1),u0(i,2),u0(i,3));
        t0(i,2) = pi/2-t0(i,2);
    end
    fun = @(t)optimize_anon(p,t,A);
    options = optimoptions('fminunc','display','iter');
    % options = optimoptions('fminunc','display','iter-detailed');
    fprintf('============================\nSearching for the optimal orientation...\n')
    % fprintf('with optimization performed inside...\n')
    % fprintf('Below only outputs outer optimization info:\n============================\n')
    warning('off','MATLAB:optim:fminunc:SwitchingMethod');
    t_opt = fminunc(fun,t0,options);
    for i=1:numOfTargets
        u(i,:) = [cos(t_opt(i,1))*sin(t_opt(i,2)) sin(t_opt(i,1))*sin(t_opt(i,2)) cos(t_opt(i,2))];
    end
    p.u = u;
end

r = optimize(p,A);

% compute the optimized E-field
[ef_all,r.xopt] = getEF(A,locs,r.sopt,hdrInfo.dim);
ef_mag = sqrt(sum(ef_all.^2,4));

% visualize the results
cm_mon = colormap(jet(64));
if strcmpi(optType,'max-l1') || strcmpi(optType,'max-l1per')
    cm_mon(3:62,:) = ones(60,3);
end
figure; mytopoplot([r.sopt; -sum(r.sopt);],'./elec72.loc','numcontour',0,'plotrad',0.9,'shading','flat','gridscale',1000,'whitebk','off','colormap',cm_mon);
                            % Ref electrode Iz is in the last one in .loc file
caxis([-2 2]); colorbar;

meshFile = [dirname filesep baseFilename '_' simTag '.mat'];
if ~exist(meshFile,'file')
    error(['Mesh file ' meshFile ' not found. Check if you run through meshing in ROAST.']);
else
    load(meshFile,'node','elem','face');
end
visualizeRes(subj,subjRSPD,opt.T2,node,elem,face,[r.sopt; -sum(r.sopt);],hdrInfo,simTag,0,r.xopt,ef_mag,ef_all);
% visualizeRes(subj,subjRSPD,opt.T2,node,elem,face,r.sopt,hdrInfo,simTag,0,A,locs,optType);
visualizeRes(subj,subjRSPD,T2,node,elem,face,injectCurrent,hdrInfo,simTag,0,vol_all,ef_mag,ef_all);
% masksFile = [dirname filesep baseFilenameRSPD '_masks.nii'];
% if ~exist(masksFile,'file')
%     error(['Segmentation masks ' masksFile ' not found. Check if you run through MRI segmentation in ROAST.']);
% else
%     masks = load_untouch_nii(masksFile);
% end
% nan_mask_brain = nan(size(masks.img)); nan_mask_brain(masks.img==1 | masks.img==2) = 1;
% E = getEF(A,locs,r.sopt,masks.img);
% for i=1:size(E,4), E(:,:,:,i) = E(:,:,:,i).*nan_mask_brain; end
% Emag = sqrt(sum(E.^2,4));
% cm_ef = colormap(jet(2048)); cm_ef = [1 1 1;cm_ef];
% for i=1:numOfTargets
%     sliceshow(Emag,targetCoord(i,:),cm_ef,[0 0.5],'Electric field (V/m)',[],E);
% end