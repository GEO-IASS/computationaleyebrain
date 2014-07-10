%% v_PTBISETBIOIrradiance
%
% Compare isetbio and ptb irradiance calculations
%
% Conclusion: They are extremely close.  But there is a small range where
% they differ slightly (2%). 
%
% The slight difference seems to be because they use slightly different
% formulae for transforming radiance to irradiance. These differ slightly.
% A discussion on the topic is in the header of the ISETBIO function
% oiCalculateIrradiance.
%
% DHB/BW (c) ISETBIO Team, 2013

%% Main parameters
s_initISET

monitorName = 'LCD-Apple.mat';
wave   = 380:4:780;
bLevel = 0.5;             % Linear value of display primaries

%% Create human optics with standard wave front aberrations

wvf    = wvfCreate('wave',wave);

pupilDiameterMm = 3;   
sample_mean = wvfLoadThibosVirtualEyes(pupilDiameterMm);
wvf    = wvfSet(wvf,'zcoeffs',sample_mean);

wvf    = wvfComputePSF(wvf);
oiB    = wvf2oi(wvf,'shift invariant');

%% ISETBIO formulation

% Write an image file with a gray background.  We want it set to one half
% the max primary intensity.  To do this, we need to read the DAC for the
% display calculate the right level.

d       = displayCreate(monitorName);
gTable  = displayGet(d,'gamma table');  % plot(gTable)
igTable = ieLUTInvert(gTable);          % Maps linear values to DAC

% It would be much better if somehow we didn't need to divide by size()
bDAC    = ieLUTLinear(repmat(bLevel,1,3),igTable)/size(gTable,1);

%% Write out the image of the background.  Then read it.
bImage = ones(128,128,3);
for ii=1:3
    bImage(:,:,ii) = bImage(:,:,ii)*bDAC(ii);
end

bFile = fullfile(isetbioRootPath,'tmp','bFile.png');
imwrite(bImage,bFile);

% Build the scene from the image file.  It would be nice if we could send
% in the data rather than the filename.
bScene = sceneFromFile(bFile,'rgb',[],monitorName,wave);
vcAddAndSelectObject(bScene); sceneWindow;

%% ISETBIO path for creating an irradiance image from the radiance

oiB    = oiCompute(oiB,bScene);
vcAddAndSelectObject(oiB); oiWindow;

% Plot the irradiance
sz = oiGet(oiB,'size');
rect = [sz(2)/2,sz(1)/2,5,5];
roiLocs = ieRoi2Locs(rect);

ibIrradiance = vcGetROIData(oiB,roiLocs,'energy');

ibIrradiance = mean(ibIrradiance,1);
vcNewGraphWin; plot(wave,ibIrradiance); grid on; title('ISET irradiance')

%% PTB path for computing the irradance

d       = displayCreate(monitorName);
wave    = displayGet(d,'wave');

% These are the linear RGB background values
backRGB = repmat(bLevel,3,1);  
backSpd = displayGet(d,'spd')*backRGB;

% Make sure we have the same focal length and pupil diameter as ISETBIO
optics = oiGet(oiB,'optics');
focalLengthMm   = opticsGet(optics,'focal length','mm');
pupilDiameterMm = opticsGet(optics,'pupil diameter','mm');
integrationTimeSec = 0.05;  % Irrelevant for irradiance

% The PTB call
[~,~,ptbPhotoreceptors,ptbIrradiance] = ...
    ptbConeIsomerizationsFromSpectra(backSpd,wave,...
    pupilDiameterMm,focalLengthMm,integrationTimeSec,0);

%% Actually, a little puzzling.  Close, but not precisely interpretable.
vcNewGraphWin([],'tall'); 

% There is a little difference in certain intensity levels.  Why?
subplot(2,1,1)
semilogy(wave,ptbIrradiance,'r--',wave,ibIrradiance,'k:');
legend('PTB','ISETBIO'); grid on; 
subplot(2,1,2)
plot(ibIrradiance,ptbIrradiance,'.')
identityLine; grid on

%% END