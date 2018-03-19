function tpm = spm_load_priors8_noBspline(V)
% Loads the tissue probability maps for segmentation without any B-spline
% FORMAT tpm = spm_load_priors8_noBspline(V)
% V  - structures of image volume information (or filenames)
% tpm - a structure for tissue probabilities
%
% This function is intended to be used in conjunction with spm_sample_priors.
% V = spm_vol(P);
% T = spm_load_priors(V);
% B = spm_sample_priors(T,X,Y,Z);
%____________________________________________________________________________
% Copyright (C) 2008 Wellcome Department of Imaging Neuroscience

% John Ashburner
% Yu (Andy) Huang
% $Id: spm_load_priors8.m 3168 2009-05-29 20:52:52Z john $

% tiny = 1e-3;
% 
% deg = 1;
if ~isstruct(V), V  = spm_vol(V); end;
spm_check_orientations(V);

tpm.V = V;
tpm.M = tpm.V(1).mat;

Kb = numel(tpm.V);
tpm.dat = cell(Kb,1);
for k1=1:(Kb),
    tpm.dat{k1} = zeros(tpm.V(1).dim(1:3));
end;

spm_progress_bar('Init',tpm.V(1).dim(3),'Loading priors','Planes loaded');
for i=1:tpm.V(1).dim(3)
    M         = spm_matrix([0 0 i]);
    s         = zeros(tpm.V(1).dim(1:2));
    for k1=1:Kb
        tmp                = spm_slice_vol(tpm.V(k1),M,tpm.V(1).dim(1:2),0);
        tpm.dat{k1}(:,:,i) = max(min(tmp,1),0);
        s                  = s + tmp;
    end;
    t = s>1;
    if any(t)
        for k1=1:Kb
            tmp           = tpm.dat{k1}(:,:,i);
            tmp(t)        = tmp(t)./s(t); % normalize the loaded TPM
            % eTPM.nii will be normalized here. Others (bTPM, cTPM, cTPMthresh) were normalized before loading.
            tpm.dat{k1}(:,:,i) = tmp;
        end;
    end;
    spm_progress_bar('Set',i);
end;
% tpm.bg1 = zeros(Kb,1);
% for k1=1:Kb,
%     tpm.bg1(k1)  = mean(mean(tpm.dat{k1}(:,:,1)));
%     tpm.bg2(k1)  = mean(mean(tpm.dat{k1}(:,:,end)));
%     tpm.dat{k1} = spm_bsplinc(log(tpm.dat{k1}+tiny),[deg deg deg  0 0 0]); % get B-spline coefficients for subsequent sampling using B-spline interpolation
% end;
% tpm.tiny = tiny;
% tpm.deg  = deg+1;
% COMMENTED OUT BY ANDY 2013-02-15

spm_progress_bar('Clear');
return;