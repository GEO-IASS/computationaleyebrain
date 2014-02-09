%% t_scene2coneAbsorption
%    This is the tutorial script for Psych 221 project
%
% (HJ) Feb, 2014

%% Init Parameters
if notDefined('ppi'), ppi = 500; end            % points per inch
if notDefined('imgFov'), imgFov = [6 6]/60; end % visual angle (degree)
if notDefined('nFrames'), nFrames = 5000; end   % Number of samples

vDist  = 1.0;                                   % viewing distance (meter)
imgSz  = round(tand(imgFov)*vDist*39.37*ppi);   % number of pixels in image
imgFov = atand(max(imgSz)/ppi/39.37/vDist);     % Actual fov

%% Create virtual display
display = displayCreate('LCD-Apple');
display = displaySet(display, 'dpi', ppi);

%% Create Scene
img = ones(imgSz)*0.5;            % Init to black
img(:, round(imgSz(2)/2)) = .99;  % Draw vertical straight line in middle
img(1:round(imgSz(1)/2), :) = circshift(img(1:round(imgSz(1)/2), :),[0 1]);

% Create scene from file
scene = sceneFromFile(img, 'rgb', [], display);

% set scene fov
scene = sceneSet(scene, 'h fov', imgFov);
scene = sceneSet(scene, 'distance', vDist);

% Visualize scene
vcAddAndSelectObject('scene', scene); sceneWindow;

%% Create Human Lens
%  Create a typical human lens
wave   = 380 : 4 : 780;
wvf    = wvfCreate('wave', wave);
pupilDiameterMm = 3; % 3 mm
sample_mean = wvfLoadThibosVirtualEyes(pupilDiameterMm);
wvf    = wvfSet(wvf,'zcoeffs',sample_mean);
wvf    = wvfComputePSF(wvf);
oi     = wvf2oi(wvf,'shift invariant');

% Compute optical image
% Actually, we could wait to compute it in coneSamples
% But, we compute it here to do sanity check
oi = oiCompute(scene, oi);

% Visualize optical image
vcAddAndSelectObject('oi', oi); oiWindow;

%% Create Sensor and Compute Samples
%  Create human sensor
sensor = sensorCreate('human');
sensor = sensorSetSizeToFOV(sensor, imgFov, scene, oi); % set fov
sensor = sensorSet(sensor, 'exp time', 0.05); % integration time: 50 ms

%  Init some parameters
%  These are parameters for eye movement. Eye movement is very tricky and
%  at first step, you could turn it off by setting Sigma to zeros(2).
%  In handling eye movement, you need to make sure that the classifier
%  cannot tell the difference between two groups based on eye movement
%  pattern or something related.
%  Here, I set the eye movement speed to be 1 ms. And sum up to the
%  exposure time
emPerExposure   = round(sensorGet(sensor, 'exp time')/0.001);
params.center   = [0,0];
params.Sigma    = 6e-5 * eye(2);
params.nSamples = nFrames + emPerExposure;
params.fov      = sensorGet(sensor,'fov',scene,oi);

%  Set exposure time to 1 ms
sensor = sensorSet(sensor, 'exp time', 0.001);

% Set up the eye movement properties
sensor = emInit('fixation', sensor, params);

% Compute the cone absopritons
sensor = coneAbsorptions(sensor, oi);

% Store the photon samples
pSamples = double(sensorGet(sensor, 'photons'));

% Add 50 samples to 1 to form the 50ms integration time
% We do use moving sum here
pSamples = RGB2XWFormat(pSamples);
pSamples = cumsum(pSamples, 2);
pSamples = pSamples(:, emPerExposure + 1:end) - ...
             pSamples(:, 1:end-emPerExposure);

% Now, each line is a sample with noise and you could use this for your
% classification

%% END