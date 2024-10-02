%% COM DSA MODEL version 5 %%
function runDsaModel5(params)

% This version 5 updates the previous version 4.5 to start the 
% projection from year 2023 on (not from 2022 on). 


% This function runs DSA model with predefinied parameters.
% Parameters must be passed in a structure called "params".
% Structure must contain below parameters with selected values.

% Definition of the parameter structure passed to the function:

   % SELECT ADJUSTMENT PLAN LENGTH:
        %  4) 4-year plan
        %  7) 7-year plan

    % SELECT SFA METHOD:
        %  0) COM New Revised Assumption
        % -1) COM Old Zero Assumption

    % IMPOSE DEBT SUSTAINABILITY SAFEGUARD:
        % yes = 1, no = 0 

    % IMPOSE DEFICIT RESILIENCE SAFEGUARD:
        % yes = 1, no = 0

    % PLOTTING:
        % yes = 1, no = 0

    % STOCHASTIC SAMPLES (Power of ten for simulated paths):
        % 3 = 1,000 simulated paths
        % 4 = 10,000 simulated paths
        % 5 = 100,000 simulated paths
        % 6 = 1,000,000 simulated paths

    % PLAUSIBILITY VALUE:
        % 7 = 70%
        % 8 = 80%
        % 9 = 90%

    % LANGUAGE FOR STOCHASTIC PLOTS:
        % 1 = English
        % 2 = Suomi (Finnish)

    % STOCHASTIC METHOD:
        % 1 = Normal Distribution Simulation
        % 2 = Bootstrap Simulation

    % SAVE RESULTS:
        % 1 = Save as .mat file
        % 0 = Do not save the results as .mat file
        
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Example to define the parameter structure and run the model:

% Define parameters in a structure
    % params = struct;
    % params.adjustmentPeriods = 4;
    % params.sfa_method = 0;
    % params.apply_debt_safeguard = 1;
    % params.apply_deficit_benchmark = 1;
    % params.apply_deficit_safeguard = 1;
    % params.plotting = 1;
    % params.power = 3;
    % params.plausibility = 7;
    % params.language = 1;
    % params.stoch_method = 1;
    % params.saveFlag = 1;

% Call the function with the parameter structure
    % runDsaModel4_5(params);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

            %%%%%%%%%%%%%%%
            % Description %
            %%%%%%%%%%%%%%%

% Code calculates minimum yearly adjustment for four/seven year adjustment plan
% for Finland considering selected criteria. If no safeguards are imposed in the
% parameter section, function imposes only DSA-based criteria and check
% debt trajectory is on a continously declining path 10-year after the adjustment
% (deterministic) & certain share of simulated 5-year debt paths is
% satisfied (stochastic). The imposed share that must be below after the 
% adjustment is selected by the user (Plausibility value).

% Code produces debt projections following the structure of 
% the European Commission's 2023 Debt Sustainability Monitor.
%
% Currently 4 scenarios are available: baseline, lower SPB,
% adverse r-g and financial stress.

% Also SFA method can be choosed to follow Commission revised assumption or
% the old zero assumption. Selection for these can be made when defining
% the parameter structure.
        
% TIMING: First period corresponds to year 2023 in data matrix.
%           2023-2024 are pre-adjustment plan periods.
%           For 4 (7) year plan 2025-2028 (2025-2031) are adjustment
%           plan periods and 2029-2038 (2032-2041) are post-adjustment 
%           plan periods. There are 16 (19) periods in total.
%
% NOTE: Code uses function project_debt5v.m to find minimum 
%           yearly adjustment which satisfy only DSA-based criteria.
%
% For comments and suggestions please contact peetu.keskinen[at]vtv[dot]fi
% 
% Author: Peetu Keskinen
% Date: 28/6/2024
%

%% Unpack parameters from the structure

adjustmentPeriods = params.adjustmentPeriods;
sfaMethod = params.sfa_method;
applyDebtSafeguard = params.apply_debt_safeguard;
applyDeficitBenchmark = params.apply_deficit_benchmark;
applyDeficitSafeguard = params.apply_deficit_safeguard;
plotting = params.plotting;

power = params.power;
plausibility = params.plausibility;
language = params.language;
stochMethod = params.stoch_method;
saveFlag = params.saveFlag;

%% PARAMETERS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

stepSize=0.01; % define step size for adjustment
adjustmentGrid = 0.01:stepSize:2;  % Grid of possible values of a

% COM calibrated initial debt shares. Derived from the model 
% and made consistent with the short-term forecast
gamma_stn = 0.007127; % short term new debt in 2023
gamma_str = 0.091360; % short term rolled over debt in 2023
gamma_o = 0.809592; % outstanding debt in 2023
gamma_ltn = 0.058688; % long term new debt in 2023
gamma_ltr = 0.033232; % long term rolled over debt in 2023

phi = 0.75; % COM assumption on fiscal multiplier on impact
epsilon = 0.582; %semi-elasticity of budget balance for Finland
rgdp_initial = 233.63499; % real gdp level in 2023
debt_initial = 75.8307 ; %debt in 2023, source:StatFin
max_deficit = -3.05; % treaty headline deficit value
benchmark_a = 0.5; % adjustment in the case of deficit benchmark applying
deficit_safeguard = -1.55; % value for deficit safeguard
format shortG


%% DEFINITIONS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

deter = 1; % use this to project debt using deterministic scenarios

if adjustmentPeriods == 7
    extra = 3; % create variable to adjust time period in the case of 7 year plan
    resilience_a = 0.25; % adjustment if deficit resilience safeguard not good
elseif adjustmentPeriods == 4
    extra = 0; % 4 year plan
    resilience_a = 0.4; % adjustment if deficit resilience safeguard not good
else
    error('Error: adjustmentPeriods must be either 4 or 7.'); % Display error message and stop program
end

pre_plan_periods = 2;   % number of periods before the adjustment plan (23-24)
adjustment_start = pre_plan_periods + 1; % start period of adjustment (2025)
adjustmentEndPeriod = pre_plan_periods + adjustmentPeriods; % end period of adjustment
post_plan_periods = 10; % periods after the adjustment plan (2028-38/2031-2041)
totalPeriods = pre_plan_periods + adjustmentPeriods + post_plan_periods;
                    
remaining = 6; % remaining year in the 4 year plan (used in share_lt_maturing)

%% DATA %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

data = readmatrix('ECdataFinland.xlsx', 'Range', 'A2:T20', 'Sheet', 'data');

potgdp = data(1:totalPeriods,2); % potential gdp level
inflation = data(1:totalPeriods,3)./100; % inflation rate
og = NaN(totalPeriods,1);
og(1:3) = data(1:3,4); % output gap
ageing = data(1:totalPeriods,5); % cost of ageing 
property = data(1:totalPeriods,20); % property income 

spb = NaN(totalPeriods,1);
spb(1:2) = data(1:2,6);    % COM estimate of spb 23-24
pb = NaN(totalPeriods,1);
pb(1:2) = data(1:2,7);     % COM estimate of pb 23-24
ob = NaN(totalPeriods,1);
ob(1:2) = data(1:2,8);     % COM estimate of ob 23-24
sb = NaN(totalPeriods,1);
sb(1:2) = data(1:2,9);     % COM estimate of sb 23-24

share_lt_maturing_t0 = data(1,14); % current share of lt maturing debt (2023)
share_lt_maturing_t10 = data(1,15); % target share of lt maturing debt (2033)

iir = NaN(totalPeriods,1);
iir(1:3) = data(1:3,16); % use 2023-2024 COM forecasts for IIR
i_st = data(1:totalPeriods,17); % short-term market interest rate
i_lt = data(1:totalPeriods,18); % long-term market interest rate

%% CREATE VARIABLES %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% define initial short and long term debt shares in total debt in 2022
alpha_initial = gamma_stn + gamma_str;
beta_initial = (gamma_ltn + gamma_ltr)/(gamma_o + gamma_ltn + gamma_ltr);

% define the time profile for the share of long term debt maturing
share_lt_maturing = linspace(share_lt_maturing_t0,share_lt_maturing_t10,10)';
share_lt_maturing = [NaN; share_lt_maturing; share_lt_maturing_t10*ones(remaining-1+extra,1)];

% Calculate ageing costs
dcoa = zeros(totalPeriods, 1);

% Initialize cumulative difference
cum_diff_dcoa = 0;

% Compute dcoa for periods from adjustmentEndPeriod + 1 up to totalPeriods
for t = (adjustmentEndPeriod + 1):totalPeriods
    % At each iteration, add the difference between ageing at t-1 and t
    cum_diff_dcoa = cum_diff_dcoa + (ageing(t - 1) - ageing(t));
    
    % Assign the cumulative difference to dcoa(t)
    dcoa(t) = -cum_diff_dcoa;
end

% Calculate property income
dprop = zeros(totalPeriods, 1);

% Initialize cumulative difference
cum_diff_dprop = 0;

% Compute dcoa for periods from adjustmentEndPeriod + 1 up to totalPeriods
for t = (adjustmentEndPeriod + 1):totalPeriods
    % At each iteration, add the difference between ageing at t-1 and t
    cum_diff_dprop = cum_diff_dprop + (property(t - 1) - property(t));
    
    % Assign the cumulative difference to dcoa(t)
    dprop(t) = cum_diff_dprop;
end

% Fiscal policy effects output gap during the consolidation 
% Commission fiscal multiplier is 0.75
m = [zeros(1,pre_plan_periods) phi*ones(1,adjustmentPeriods)...
    zeros(1,post_plan_periods)]';

% Create Debt Sustainability Safeguard
if debt_initial>=60 && debt_initial<=90
    debt_safeguard=-0.5; % debt must decline 0.5 %-points per year
elseif debt_initial>90
    debt_safeguard=-1; % debt must decline 1.0 %-points per year
else
    disp('Debt below 60%, Debt Sustainability safeguard not needed.');
end

%% SFA METHOD %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% COM new revised assumption for Finland
if sfaMethod == 0    
    
        sfa=data(1:end,19); % sfa data from 2023 on

% COM old zero assumption (from T+2 period on sfa=0)
elseif sfaMethod == -1       
        sfa=data(1:end,19);   % sfa data from 2023 on
        sfa(4:end) = 0;
end


%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% CALCULATE DEBT PATHS FOR ALL DETERMINISTIC SCENARIOS WITH ALL VALUES OF ADJUSTMENT %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Go through all deterministic scenarios in order and find minimum
% adjustment
disp('**********************************************');
disp('***** DSA-BASED CRITERIA (deterministic) *****');
disp('**********************************************');
fprintf('\n');  % This creates an empty line in the output

for scenario = 4:-1:1 %loop through all deterministic scenarios
 
% Loop over each adjustmentGrid value of adjustment in the grid
debtPaths = NaN(totalPeriods,length(adjustmentGrid)); % shell for debt
nominalGrowthPaths = NaN(totalPeriods,length(adjustmentGrid)); % shell for nominal growth
realGrowthPaths = NaN(totalPeriods,length(adjustmentGrid)); % shell for real growth
obPaths = NaN(totalPeriods,length(adjustmentGrid)); % shell for overall balance
sbPaths = NaN(totalPeriods,length(adjustmentGrid)); % shell for structural balance
sbpPaths = NaN(totalPeriods,length(adjustmentGrid)); % shell for structural primary balance
realGDPPaths = NaN(totalPeriods,length(adjustmentGrid)); % shell for real GDP

% Calculate paths for ALL values of adjustmentGrid
for i = 1:length(adjustmentGrid)
    [debtPaths(:,i),nominalGrowthPaths(:,i),realGrowthPaths(:,i),~,~,sbpPaths(:,i),obPaths(:,i),sbPaths(:,i),realGDPPaths(:,i)] = project_debt5v(scenario,adjustmentGrid(i), iir, potgdp,...
        og, epsilon,m,dcoa,dprop,sfa,inflation,rgdp_initial, debt_initial,alpha_initial,beta_initial, spb,...
        i_st,i_lt,...
        share_lt_maturing,pb,ob,sb,deter,zeros(totalPeriods,1),...
        zeros(totalPeriods,1),zeros(totalPeriods,1),adjustmentPeriods);
end

%Start checking the minimum adjustment until declining=true
    
detOptimalIndex = 0;  % Initialize to 0 to indicate no solution found


%% CHECK DSA-BASED CRITERIA (deterministic scenario)

% Declining debt path & 3% deficit limit during 10 year review period 
    for j = 1:size(debtPaths,2)  % Loop through columns of debtPaths
        if all(diff(debtPaths(adjustmentEndPeriod:end,j)) < 0)
            % Check additional condition only if scenario == 1
            if scenario == 1 && all(obPaths(adjustmentEndPeriod:end,j) > max_deficit)
                detOptimalIndex = j;
                break;  % Exit the loop once the condition is met
            elseif scenario ~= 1
                detOptimalIndex = j;
                break;  % Exit the loop for other scenarios without the second condition
            end
        end
    end



if detOptimalIndex == 0
    disp('No value could be found that satisfies the condition.');
else
    optimalAdjustment = adjustmentGrid(detOptimalIndex); % minimum consolidation a*
    finalStructuralPrimaryBalance = sbpPaths(adjustmentEndPeriod, detOptimalIndex);  % Extract the value
    X = ['Scenario is: ', num2str(scenario), ', a*=', num2str(optimalAdjustment), ', SPB*=', num2str(finalStructuralPrimaryBalance, '%.2f'), ', ', num2str(adjustmentPeriods), ' year plan.'];
    disp(X)

  %disp(['Minimum adjustment by DSA-based criteria (Deterministic) is a*=', num2str(optimalAdjustment)]);
end
end

%% PROJECT DEBT IN ADJUSTMENT SCENARIO USING MINIMUM ADJUSTMENT a*
% this is done for later plotting purposes
% calculate debt path with minimum adjustment satisfying the selected criteria 
    [debt_path,optimal_Gn,optimal_Gr,iir_path,pb_path,spb_path,ob_path,sb_path,~] = project_debt5v(scenario,optimalAdjustment, iir, potgdp,...
        og, epsilon,m,dcoa,dprop,sfa,inflation,rgdp_initial, debt_initial,alpha_initial,beta_initial, spb,...
        i_st,i_lt,...
        share_lt_maturing,pb,ob,sb,deter,zeros(totalPeriods,1),...
        zeros(totalPeriods,1),zeros(totalPeriods,1),adjustmentPeriods);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%% STOCHASTIC SCENARIO %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Load quarterly first differenced data 1999Q2-2022Q4
% data in terms of %-points of GDP
% Columns: short-term interest rate (%-points), 
%          long-term interest rate (%-points), 
%          nominal gdp growth (%-points), 
%          primary balance (%-points)

% CHECK SCENARIOS NUMBERS!

dataStoch = readmatrix('ECdataFinland.xlsx', 'Range', 'I3:L97', 'Sheet', 'STOCH');
dataStochBoot = readmatrix('ECdataFinland.xlsx', 'Range', 'C3:F49', 'Sheet', 'STOCH'); 
% C3 (1976)/ C17 (1990) / C26 1999
meanValues = mean(dataStoch);
stdDevValues = std(dataStoch);
% correct for outliers
outlier_threshold = 3;
lowerThreshold = meanValues - outlier_threshold * stdDevValues;
upperThreshold = meanValues + outlier_threshold * stdDevValues;
% Clip values based on the thresholds
dataClipped = max(dataStoch, lowerThreshold);
dataClipped = min(dataClipped, upperThreshold);
% Create a logical mask for replaced values
replacedMask = (dataClipped ~= dataStoch);
% Calculate the number of replaced values
numReplacedValues = nnz(replacedMask);
disp(['Number of replaced outlier values: ', num2str(numReplacedValues)]);
fprintf('\n');  % This creates an empty line in the output

%% Parameters
share_lt_maturing_t10 = 0.036601;% ECB data, REMOVE ONCE MERGED
nbr_q = 4; % number of quarters in a year
T_stochastic = 5; % years affected by stochastic shocks
nbr_q_shocks = 20*10^power; % number of quarterly shocks to generate
pre_stoch = adjustmentEndPeriod; % pre stochastic years before the plan
post_stoch = 5; % post stochastic years in evaluation phase

%% Definitions
nbr_vars = size(dataClipped,2); % number of variables
nbr_q_gen = nbr_q*T_stochastic; % quarters affected by stochastic shocks
nbr_sim_paths = nbr_q_shocks/nbr_q_gen; % number of 5-year forecasts (sim. debt paths)
nbr_y_shocks = nbr_q_shocks/nbr_q; % number of years in the forecast 
% Average maturity
m_res_lt = 1/share_lt_maturing_t10; % average residual maturity of lt bonds
%maturity_quarters = nbr_q*m_res_lt; % average residual maturity in quarters

% Name methods
if stochMethod == 1
    methodName = 'normal';
elseif stochMethod == 2
    methodName = 'boot';
else
    methodName = 'unknown';
end

%% Generate quarterly shocks
% Sampling methods
if stochMethod == 1
    % Normal Random Sampling
    mu = zeros(1, nbr_vars);
    sigma = cov(dataClipped);
    randSamples = mvnrnd(mu, sigma, nbr_q_shocks);
    Sample = randSamples; 

    % reshape into yearly 4x4 matrices. now row: vars, column: quarter)
    Rands=reshape(Sample',[nbr_q,nbr_vars,nbr_y_shocks]); % reshape

    %% Aggregate quarterly shocks to yearly
    % create shell for yearly shocks
    Shock = zeros(nbr_y_shocks,nbr_vars); 
    % store yearly shocks
    e_i_st = zeros(nbr_sim_paths,T_stochastic); % shells
    e_g = zeros(nbr_sim_paths,T_stochastic);
    e_pb = zeros(nbr_sim_paths,T_stochastic);

    % get yearly shock by summing quarterly shocks
    for i=1:nbr_y_shocks
    Shock(i,:)=sum(Rands(:,:,i),2)';
    end

    % reshape (variable, 5-year forecast, N copies)
    Shock = reshape(Shock',[nbr_vars T_stochastic nbr_sim_paths]);

    for i=1:nbr_sim_paths
    e_i_st(i,:) = Shock(1,:,i); % short term market interest rate
    e_g(i,:) = Shock(3,:,i);    % nominal gdp growth rate
    e_pb(i,:) = Shock(4,:,i);   % primary balance
    end

%% Construct long term interest rate shocks
    shock_i_lt = Sample(:,2); % generated quarterly i_lt shocks
    % use function sumq2y to get persistent yearly shocks
    [e_i_lt] = sumq2y(shock_i_lt,m_res_lt,T_stochastic);

    % add zeros to get correct dimensions
    % iir shock
    i_st_shock = [zeros(pre_stoch,nbr_sim_paths); e_i_st'; zeros(post_stoch,nbr_sim_paths)];
    i_lt_shock = [zeros(pre_stoch,nbr_sim_paths); e_i_lt'; zeros(post_stoch,nbr_sim_paths)];

    iir_shock = alpha_initial.*i_st_shock + (1-alpha_initial).*i_lt_shock; 
    % gdp and pb shocks
    g_shock = [zeros(pre_stoch,nbr_sim_paths); e_g'; zeros(post_stoch,nbr_sim_paths)];
    pb_shock = [zeros(pre_stoch,nbr_sim_paths); e_pb'; zeros(post_stoch,nbr_sim_paths)];

%% Project debt paths under stochastic scenarios

    % shell for final 3D stochastic debt matrix 
    D_stoch = zeros(totalPeriods,length(adjustmentGrid),nbr_sim_paths);

    % Initialize waitbar
    h = waitbar(0, 'Running simulations...');

    % Loop through stochastic shocks...
    for k = 1:nbr_sim_paths

        % Update waitbar
        waitbar(k/nbr_sim_paths, h, sprintf('Calculate stochastic debt path %d of %d', k, nbr_sim_paths));

        D_temp = zeros(totalPeriods,length(adjustmentGrid)); % shell
        iir_stoch = iir_shock(:,k); % iir
        g_stoch = g_shock(:,k); % nominal gdp growth
        pb_stoch = pb_shock(:,k); % primary balance

        % ... and through values of adjustmentGrid
        for i = 1:length(adjustmentGrid)

            [D_temp(:,i),~,~,~,~,~,~,~,~] = project_debt5v(scenario,adjustmentGrid(i), iir, potgdp,...
                og, epsilon,m,dcoa,dprop,sfa,inflation,rgdp_initial, debt_initial,alpha_initial,beta_initial, spb,...
               i_st,i_lt,...
                share_lt_maturing,pb,ob,sb,stochMethod,g_stoch,...
                pb_stoch,iir_stoch,adjustmentPeriods);
        end

    % store 2D matrix
    D_stoch(:,:,k) = D_temp;
    end

    % Close waitbar after completion
    close(h);

elseif stochMethod == 2

    % Shell for final 3D stochastic debt matrix 
    D_stoch = zeros(totalPeriods, length(adjustmentGrid), nbr_sim_paths);

    % Sampling with Block-Bootstrap Approach
    blockSize = 2; % Set block size between 1 and 5
    nbr_boots = 5; % Total number of periods to generate in one simulation

    % Compute the number of blocks needed
    numBlocks = ceil(nbr_boots / blockSize);

    % Load Stoch Boot data (d_rgdp, pb, iir, sfa)
    sampleSize = size(dataStochBoot, 1); % Sample size

    % Initialize bootstrapSamples as a 3D array
    bootstrapSamples = zeros(totalPeriods, size(dataStochBoot, 2), nbr_sim_paths);

    % Create block bootstrap sample
    for i = 1:nbr_sim_paths

        % Preallocate blockStartIdx with zeros
        blockStartIdx = zeros(nbr_boots, 1);

        currentIdx = 1; % Initialize the index to place the block indices

        for b = 1:numBlocks
            % Draw a random starting index for the block
            blockStart = randi([1, sampleSize - blockSize + 1]);

            % Generate indices for the block of size blockSize
            blockIndices = blockStart : blockStart + blockSize - 1;

            % Determine how many indices we can copy without exceeding nbr_boots
            numIndicesToCopy = min(blockSize, nbr_boots - currentIdx + 1);

            % Copy the indices into blockStartIdx
            blockStartIdx(currentIdx : currentIdx + numIndicesToCopy - 1) = blockIndices(1:numIndicesToCopy)';

            % Update currentIdx
            currentIdx = currentIdx + numIndicesToCopy;

            % If we've filled blockStartIdx, exit the loop
            if currentIdx > nbr_boots
                break;
            end
        end

        % Select the data for the current simulation path
        selectedBlock = dataStochBoot(blockStartIdx, :);

        % Determine where to place the selected block in bootstrapSamples
        bootStart = adjustmentEndPeriod + 1;
        bootEnd = adjustmentEndPeriod + nbr_boots;

        % Store the selected data in the 3D array
        bootstrapSamples(bootStart:bootEnd, :, i) = selectedBlock;
    end

    % Initialize waitbar
    h = waitbar(0, 'Running simulations...');

    % Loop through stochastic shocks...
    for k = 1:nbr_sim_paths

        % Update waitbar
        waitbar(k / nbr_sim_paths, h, sprintf('Calculate stochastic debt path %d of %d', k, nbr_sim_paths));

        D_temp = zeros(totalPeriods, length(adjustmentGrid)); % Temporary matrix for current simulation

        % Extract variables for the current simulation
        g_stoch = bootstrapSamples(:, 1, k);  % Nominal GDP growth
        pb_stoch = bootstrapSamples(:, 2, k); % Primary balance
        iir_stoch = bootstrapSamples(:, 3, k); % Implicit interest rate

        % Loop through values of 'adjustmentGrid'
        for idx_a = 1:length(adjustmentGrid)
            [D_temp(:, idx_a), ~, ~, ~, ~, ~, ~, ~, ~] = project_debt5v(...
                scenario, adjustmentGrid(idx_a), iir, potgdp, og, epsilon, m, dcoa, dprop, sfa, inflation, ...
                rgdp_initial, debt_initial, alpha_initial, beta_initial, spb, i_st, i_lt, ...
                share_lt_maturing, pb, ob, sb, stochMethod, g_stoch, pb_stoch, iir_stoch, adjustmentPeriods);
        end

        % Store the results in the 3D matrix
        D_stoch(:, :, k) = D_temp;
    end

    % Close waitbar after completion
    close(h);

else
    error('Invalid selection. Please choose 1 or 2.');
end

%% STOCHASTIC DEBT PATHS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%                
% Initialize variables and load data

horizon=T_stochastic+adjustmentPeriods+pre_plan_periods;

range = 10:10:90; % percentile range 10% to 90%
% Empty shell (horizon, number of percentiles, number of adjustment values)
debt_path_stoch = zeros(horizon, length(range), length(adjustmentGrid));

% calculate percentiles
for k = 1:length(adjustmentGrid)
    for j = 1:horizon
        debt_path_stoch(j, :,k) = prctile(D_stoch(j,k, :), range);
    end
end

%Start checking the minimum adjustment until plausibility ok, then declining=true
stochOptimalIndex = 0;  % Initialize to 0 to indicate no solution found

%% HIGH PROBABILITY OF DECLINING DEBT 

% Check the plausibility criteria
for l = 1:length(adjustmentGrid)  % Loop through values of adjustmentGrid
    % must be less in the last period than after the adjustment period
    if debt_path_stoch(horizon,plausibility,l) < debt_path_stoch(adjustmentEndPeriod,plausibility,l)

        stochOptimalIndex = l;
        debt_path_success = debt_path_stoch(:,:,stochOptimalIndex);
        break;  % Exit the loop once the condition is met
    end
end

disp('**********************************************');
disp('***** DSA-BASED CRITERIA (stochastic) ********');
disp('**********************************************');
fprintf('\n');  % This creates an empty line in the output

if stochOptimalIndex == 0
    disp('No value could be found that satisfies the condition.');
else
    optimal_stoch_a = adjustmentGrid(stochOptimalIndex); % minimum consolidation a*
    X = ['Shock generation method is: ',num2str(stochMethod),', a*=', num2str(optimal_stoch_a),', ',num2str(adjustmentPeriods),' year plan.'];
    disp(X)
    fprintf('\n');  % This creates an empty line in the output
end

if saveFlag == 1
    save('LastStochModel.mat','-v7.3','-nocompression')
end


%% CREATE DEBT, OB AND SB PATH TO CHECK SAFEGUARDS/BENCHMARK


if applyDebtSafeguard == 1 || applyDeficitBenchmark == 1 || applyDeficitSafeguard == 1 
scenario = 1; % set scenario to adjustment scenario

% Loop over each a value of adjustment in the grid
D_safeguard = NaN(totalPeriods,length(adjustmentGrid)); % shell for debt
sb_safeguard = NaN(totalPeriods,length(adjustmentGrid)); % shell for structural balance
ob_benchmark = NaN(totalPeriods,length(adjustmentGrid)); % shell for overall balance
pb_deficit = NaN(totalPeriods,length(adjustmentGrid)); % shell for primary deficit

    % Calculate paths for ALL values of adjustmentGrid
    for i = 1:length(adjustmentGrid)
        [D_safeguard(:,i),~,~,~,pb_deficit(:,i),~,ob_benchmark(:,i),sb_safeguard(:,i),~] = project_debt5v(scenario,adjustmentGrid(i), iir, potgdp,...
            og, epsilon,m,dcoa,dprop,sfa,inflation,rgdp_initial, debt_initial,alpha_initial,beta_initial, spb,...
            i_st,i_lt,...
            share_lt_maturing,pb,ob,sb,deter,zeros(totalPeriods,1),...
            zeros(totalPeriods,1),zeros(totalPeriods,1),adjustmentPeriods);
    end
end    
    
%% CHECK DEBT SUSTAINABILITY SAFEGUARD
disp('*****************************************');
disp('***** DEBT SUSTAINABILITY SAFEGUARD *****');
disp('*****************************************');
fprintf('\n');  % This creates an empty line in the output

debtSustOptimalIndex = 0;  % Initialize to 0 to indicate no solution found

if applyDebtSafeguard == 1
    % Start checking the minimum adjustment until declining = true
    for j = 1:length(adjustmentGrid)  % Loop through columns of debtPaths
        if mean(diff(D_safeguard(adjustment_start-1:adjustmentEndPeriod, j))) < debt_safeguard
            debtSustOptimalIndex = j;
            break;  % Exit the loop once the condition is met
        end
    end

    if debtSustOptimalIndex == 0
        disp('No value could be found that satisfies the debt safeguard. Increase the grid.');
    else
        optimal_a_debt = adjustmentGrid(debtSustOptimalIndex); % minimum consolidation a*
        fprintf('Scenario is: %d, a* = %.2f, %d year plan.\n', scenario, optimal_a_debt, adjustmentPeriods);
    end
else
    disp('No need to check debt sustainability safeguard.');
    fprintf('\n');  % This creates an empty line in the output
end

% Store max adjustment from already checked criteria (DSA-based and debt sustainability safeguard)
maxOptimalIndex = max([detOptimalIndex, stochOptimalIndex, debtSustOptimalIndex]);

% Preallocate final_adjustment_path to avoid dynamically resizing in the loop
final_adjustment_path = ones(adjustmentPeriods, 1) * adjustmentGrid(maxOptimalIndex);

%% CHECK DEFICIT BENCHMARK
disp('*****************************');
disp('***** DEFICIT BENCHMARK *****');
disp('*****************************');
fprintf('\n');  % This creates an empty line in the output

if applyDeficitBenchmark == 1 && adjustmentGrid(maxOptimalIndex) < benchmark_a
    % Check if overall balance violates the deficit benchmark
    ob_check = ob_benchmark(adjustment_start-1:adjustmentEndPeriod-1, maxOptimalIndex) > max_deficit;
    
    % Check compliance and adjust the path if necessary
    if sum(ob_check) < adjustmentPeriods
        % Update adjustment path for periods violating the benchmark
        final_adjustment_path(~ob_check) = benchmark_a;
        
        % adjustment in SB terms from 2028 on
        interest_benchmark = pb_deficit(adjustment_start:adjustmentEndPeriod, maxOptimalIndex) - ...
                            ob_benchmark(adjustment_start:adjustmentEndPeriod, maxOptimalIndex);
        
        
        disp('DSA-based criteria does not satisfy deficit resilience safeguard.');
    else
        disp('DSA-based criteria satisfies deficit resilience safeguard.');
    end
else
    disp('No need to check deficit benchmark.');
    fprintf('\n');  % This creates an empty line in the output
end

%% CHECK DEFICIT RESILIENCE SAFEGUARD
disp('****************************************');
disp('***** DEFICIT RESILIENCE SAFEGUARD *****');
disp('****************************************');
fprintf('\n');  % This creates an empty line in the output

if applyDeficitSafeguard == 1 && adjustmentGrid(maxOptimalIndex) < resilience_a
    % Check if structural balance violates the deficit resilience safeguard
    sb_check = sb_safeguard(adjustment_start-1:adjustmentEndPeriod-1, maxOptimalIndex) > deficit_safeguard;
    
    % Check compliance and adjust the path if necessary
    if sum(sb_check) < adjustmentPeriods
        % Find the indices where safeguard is not met
        sb_check_ind = ~sb_check;
        
        % Update adjustment path only if resilience_a is greater than the current value
        final_adjustment_path(sb_check_ind) = max(final_adjustment_path(sb_check_ind), resilience_a);
        
        disp('DSA-based criteria does not satisfy deficit resilience safeguard.');
        fprintf('\n');  % This creates an empty line in the output
    else
        disp('DSA-based criteria satisfies deficit resilience safeguard.');
        fprintf('\n');  % This creates an empty line in the output
    end
else
    disp('No need to check deficit resilience safeguard.');
    fprintf('\n');  % This creates an empty line in the output
end

% Generate the years for the adjustment path
adj_time = (2025:2028+extra)'; 

% Show final adjustment path
disp('*****************************************************');
disp('***** Final Adjustment Path, pp. (in SPB terms) *****');
disp('*****************************************************');
fprintf('\n');  % This creates an empty line in the output

disp([adj_time, final_adjustment_path]);  % Display years alongside the adjustment path values


%% DETERMINISTIC PLOTTING

if plotting == 1
    %% Plot 2D the debt path and related variables
    FigSize = 600; %set figure size
    time =(2023:2038+extra)'; 
    figure(1);
    set(gca,'fontname','Calibri') 
    subplot(1,3,1);
    plot(time, debt_path, '-o', 'LineWidth', 2,'Color','#002C5F');
    title('(a)','FontSize',20,'FontName', 'Calibri')
    ylim([60 max(debt_path)+10])
    ylabel('Velkasuhde, %','FontSize',20,'FontName', 'Calibri');
    legend('Velka/BKT','Location','southeast','FontName', 'Calibri'...
        ,'FontSize',8);
    grid on;

    subplot(1,3,2);
    plot(time, spb_path, '-o', 'LineWidth', 2,'Color','#002C5F');
    hold on
    plot(time, sb_path, '--', 'LineWidth', 2,'Color','#FF6875');
    plot(time, ob_path, 'LineWidth', 2,'Color','#FDB74A');
    title('(b)','FontSize',20,'FontName', 'Calibri')
    ylabel('% suhteessa BKT:hen','FontSize',20,'FontName', 'Calibri');
    legend({"Rakenteellinen perusjäämä" + newline + "(ikäsidonnaisilla menoilla korjattu)",'Rakenteellinen jäämä','Jäämä'},'Location','southeast',...
        'FontSize',8,'FontName', 'Calibri');
    grid on;

    subplot(1,3,3);
    plot(time, 100*optimal_Gn, '-o', 'LineWidth', 2,'Color','#002C5F');
    hold on
    plot(time, iir_path, '--', 'LineWidth', 2,'Color','#FF6875');
    plot(time, 100*optimal_Gr, 'LineWidth', 2,'Color','#FDB74A');
    title('(c)','FontSize',20,'FontName', 'Calibri')
    %title('$g_{t}$ \& $r_{t}$','interpreter','latex',...
    %   'FontSize',20,'FontName', 'Calibri')
    ylabel('vuosikasvu, %','FontSize',20,'FontName', 'Calibri');
    legend('Nimellinen BKT-kasvu','Nimellinen Korkotaso','Reaalinen BKT-kasvu','Location',...
        'southeast','FontName', 'Calibri','FontSize',8);
    grid on;
    if scenario==1
    sgtitle('Perusura','FontSize',24,'FontName', 'Calibri');
    elseif scenario==2
    sgtitle('Epäsuotuisa SPB','FontSize',24,'FontName', 'Calibri');
    elseif scenario==3
    sgtitle('Epäsuotuisa r-g','FontSize',24,'FontName', 'Calibri');
    elseif scenario==4
    sgtitle('Rahoitusmarkkinahäiriö','FontSize',24,'FontName', 'Calibri');
    end
    % Set the figure size
    set(gcf, 'Position', [20 20 2*FigSize FigSize]);

    % Save figure data %
    if scenario==1
    PlotDataAdj=[time debt_path spb_path pb_path...
                100*optimal_Gn 100*iir_path 100*optimal_Gr];
    % Assuming PlotDataLowerAdj is a matrix with the correct number of columns to match the headers.
    headers = {'vuosi', 'velkasuhde', 'rakenteellinen perusjaama',...
        'perusjaama', 'nimellinen bkt kasvu', 'nimellinen korkotaso', 'reaalinen bkt kasvu'};
    % Convert the matrix to a table
    T = array2table(PlotDataAdj, 'VariableNames', headers);
    % Write the table to a text file with headers
    writetable(T, "PlotDataAdj.txt", 'Delimiter', ' ');
    print('Adjustment','-dpng', '-r300','-cmyk');

    elseif scenario==2
    PlotDataLowerSPB=[time debt_path spb_path pb_path...
                100*optimal_Gn 100*iir_path 100*optimal_Gr];
    % Assuming PlotDataLowerSPB is a matrix with the correct number of columns to match the headers.
    headers = {'vuosi', 'velkasuhde', 'rakenteellinen perusjaama',...
        'perusjaama', 'nimellinen bkt kasvu', 'nimellinen korkotaso', 'reaalinen bkt kasvu'};
    % Convert the matrix to a table
    T = array2table(PlotDataLowerSPB, 'VariableNames', headers);
    % Write the table to a text file with headers
    writetable(T, "PlotDataLowerSPB.txt", 'Delimiter', ' ');
    print('LowerSPB', '-dpng', '-r300','-cmyk');
    
        elseif scenario==3
    PlotDataAdverseR_G=[time debt_path spb_path pb_path...
                100*optimal_Gn 100*iir_path 100*optimal_Gr];
    % Assuming PlotDataArverseR_G is a matrix with the correct number of columns to match the headers.
    headers = {'vuosi', 'velkasuhde', 'rakenteellinen perusjaama',...
        'perusjaama', 'nimellinen bkt kasvu', 'nimellinen korkotaso', 'reaalinen bkt kasvu'};
    % Convert the matrix to a table
    T = array2table(PlotDataAdverseR_G, 'VariableNames', headers);
    % Write the table to a text file with headers
    writetable(T, "PlotDataAdverseR_G.txt", 'Delimiter', ' ');
    print('AdverseR_G', '-dpng', '-r300','-cmyk');
    
        elseif scenario==4
    PlotDataFinancialStress=[time debt_path spb_path pb_path...
                100*optimal_Gn 100*iir_path 100*optimal_Gr];
    % Assuming PlotDataFinancialStress is a matrix with the correct number of columns to match the headers.
    headers = {'vuosi', 'velkasuhde', 'rakenteellinen perusjaama',...
        'perusjaama', 'nimellinen bkt kasvu', 'nimellinen korkotaso', 'reaalinen bkt kasvu'};
    % Convert the matrix to a table
    T = array2table(PlotDataFinancialStress, 'VariableNames', headers);
    % Write the table to a text file with headers
    writetable(T, "PlotDataFinancialStress.txt", 'Delimiter', ' ');
    print('FinancialStress', '-dpng', '-r300','-cmyk');
    end

    %% Plot 3D plots (real gdp growth)
    % Define the colors in RGB, normalized to [0, 1]
    color1 = [204, 213, 223] / 255; % Light blue 2
    color2 = [153, 171, 191] / 255; % Light blue 1
    color3 = [102, 128, 159] / 255; % Medium blue 2
    color4 = [51, 86, 127] / 255;   % Medium blue 1
    color5 = [0, 44, 95] / 255;     % Dark blue

    % Preallocate an array for the colormap
    numColors = 10;
    customColormap = zeros(numColors, 3);

    % Generate intermediate colors using linspace
    for i = 1:3 % For each color channel
        % Combine all five colors' current channel into an array
        originalChannels = [color1(i), color2(i), color3(i), color4(i), color5(i)];
        % Interpolate to find two intermediate colors between each original color
        customColormap(:, i) = interp1(1:length(originalChannels), originalChannels, linspace(1, length(originalChannels), numColors));
    end

    % Apply the custom colormap to the current figure
    colormap(customColormap);
    figure(2);
    %subplot(1,2,1);
    ax1 = gca;  % Get handle to current axes
    x1 = time;
    y1 = adjustmentGrid;
    [X1, Y1] = meshgrid(x1, y1);
    Z1 = 100 * realGrowthPaths;
    surf(Y1', X1', Z1, 'FaceAlpha', 1);
    xlabel('$a$', 'Interpreter', 'latex', 'FontSize', 20)
    zlabel('BKT-kasvu, %', 'FontSize', 20, 'FontName', 'Calibri');
    zlim([0 max(100*realGrowthPaths,[], 'all') + 1])
    colormap(ax1, customColormap); 
    set(gcf, 'Position', [250 250 FigSize FigSize]);

    %% 2D plots (real gdp growth)
    % Assuming realGrowthPaths is the matrix with real GDP growth rates where rows correspond
    % to different years and columns to different values of 'adjustmentGrid'

    % Values of 'adjustmentGrid' from the grid
    a_grid = adjustmentGrid;

    % Logical indexing to find indices for min, max, and median 'adjustmentGrid'
    min_a_idx = a_grid == min(a_grid);
    max_a_idx = a_grid == max(a_grid);
    median_a_idx = a_grid == median(a_grid);

    % Extract the real GDP growth paths for min, max, and median 'adjustmentGrid'
    min_a_growth = realGrowthPaths(:, min_a_idx);
    max_a_growth = realGrowthPaths(:, max_a_idx);
    median_a_growth = realGrowthPaths(:, median_a_idx);

    % Plotting the real GDP growth paths for selected 'adjustmentGrid' values
    figure;
    hold on
    plot(time, 100 * min_a_growth, '-o', 'LineWidth', 2, 'Color', '#002C5F', 'DisplayName', sprintf('a = %.1f (Min)', min(a_grid)));
    hold on;
    plot(time, 100 * max_a_growth, '--o', 'LineWidth', 2, 'Color', '#FF6875', 'DisplayName', sprintf('a = %.1f (Max)', max(a_grid)));
    plot(time, 100 * median_a_growth, 'LineWidth', 2, 'Color', '#FDB74A', 'DisplayName', sprintf('a = %.1f (Median)', median(a_grid)));
    hold off;

    % Add labels and title
    xlabel('Year', 'FontSize', 14, 'FontName', 'Calibri');
    ylabel('Real GDP Growth (%)', 'FontSize', 14, 'FontName', 'Calibri');
    title('Real GDP Growth for Different Adjustment Values', 'FontSize', 16, 'FontName', 'Calibri');

    % Add legend
    legend('show', 'Location', 'best', 'FontName', 'Calibri');

    % Grid on for better readability
    grid on;

    % Set the figure size
    set(gcf, 'Position', [100 500 1.5*FigSize 1*FigSize]);

    if scenario==1
    % Increase the resolution to 300 dpi
    print('Adjustment2DrealGDP','-dpng', '-r300','-cmyk');
    elseif scenario==2
    % Increase the resolution to 300 dpi
    print('Lower2DrealGDP','-dpng', '-r300','-cmyk');
    elseif scenario==3
    % Increase the resolution to 300 dpi
    print('AdverseR_G2DrealGDP','-dpng', '-r300','-cmyk');
    elseif scenario==4
    % Increase the resolution to 300 dpi
    print('FinancialStress2DrealGDP','-dpng', '-r300','-cmyk');
    end
    
    %% Plot 3D plots (debt-to-gdp ratio)
    figure(3)
    ax2 = gca;  % Get handle to current axes
    x2 = time;
    y2 = adjustmentGrid;
    [X2, Y2] = meshgrid(x2, y2);
    Z2 = debtPaths;
    surf(Y2', X2', Z2, 'FaceAlpha', 1);
    xlabel('$a$', 'Interpreter', 'latex', 'FontSize', 20)
    zlabel('Velka/BKT', 'FontSize', 20, 'FontName', 'Calibri');
    view( 156.5618,  12.3745); %adjust view angle
    zlim([0  max(debtPaths(end,:))+10])
    colormap(ax2, customColormap);  % Apply custom colormap to second subplot

    % Set color data based on Z-values (debt ratio change)
    caxis(ax2, [40, 90]);
    % Add colorbar
    colorbar('Position', [0.95, 0.17, 0.02, 0.8], 'FontSize', 14, 'FontName', 'Calibri');

    % Set the font name for all text objects in the current figure
    set(gca, 'FontName', 'Calibri');       % Change font for axes tick labels
    set(findall(gcf,'type','text'), 'FontName', 'Calibri'); % Change font for titles, labels, legends, etc.

    % Change the font size as well
    set(gca, 'FontSize', 20);            % Change font size for axes tick labels
    set(findall(gcf,'type','text'), 'FontSize', 20); % Change font size for titles, labels, legends, etc.

    % Set the figure size
    set(gcf, 'Position', [100 500 1.5*FigSize 1.5*FigSize]);

    if scenario==1
    % Increase the resolution to 300 dpi
    print('Adjustment3D','-dpng', '-r300','-cmyk');
    elseif scenario==2
    % Increase the resolution to 300 dpi
    print('Lower3D','-dpng', '-r300','-cmyk');
    elseif scenario==3
    % Increase the resolution to 300 dpi
    print('AdverseR_G3D','-dpng', '-r300','-cmyk');
    elseif scenario==4
    % Increase the resolution to 300 dpi
    print('FinancialStress3D','-dpng', '-r300','-cmyk');
    end
    
    %% Bird view plot (debt-to-gdp ratio)
    figure(4)
    ax2 = gca;  % Get handle to current axes
    x2 = time;
    y2 = adjustmentGrid;
    [X2, Y2] = meshgrid(x2, y2);
    Z2 = debtPaths;
    surf(Y2', X2', Z2, 'FaceAlpha', 1);
    xlabel('$a$', 'Interpreter', 'latex', 'FontSize', 20)
    zlabel('Velka/BKT', 'FontSize', 20, 'FontName', 'Calibri');
    view(2); % Adjust th view angle
    zlim([0  max(debtPaths(15,:))+10])
    colormap(ax2, customColormap);  % Apply custom colormap to second subplot

    % Set color data based on Z-values (debt ratio change)
    caxis(ax2, [40, 90]);
    colorbar

    if scenario==1
    sgtitle('Perusura','FontSize',30,'FontName', 'Calibri');
    elseif scenario==2
    sgtitle('Epäsuotuisa SPB','FontSize',30,'FontName', 'Calibri');
    elseif scenario==3
    sgtitle('Epäsuotuisa r-g','FontSize',30,'FontName', 'Calibri');
    elseif scenario==4
    sgtitle('Rahoitusmarkkinahäiriö','FontSize',30,'FontName', 'Calibri');
    end

    % Set the figure size
    set(gcf, 'Position', [200 600 FigSize FigSize]);

    if scenario==1
    % Increase the resolution to 300 dpi
    print('AdjustmentBird','-dpng', '-r300','-cmyk');
    elseif scenario==2
    % Increase the resolution to 300 dpi
    print('LowerBird','-dpng', '-r300','-cmyk');
    elseif scenario==3
    % Increase the resolution to 300 dpi
    print('AdverseR_GBird','-dpng', '-r300','-cmyk');
    elseif scenario==4
    % Increase the resolution to 300 dpi
    print('FinancialStressBird','-dpng', '-r300','-cmyk');
    end

elseif plotting==0
    disp(['*Plotting not selected*']);
else
    disp(['Define plotting variable']);
end

%% STOCHASTIC PLOTTING 

figure;
hold on;
FigSize = 600;
% Change the axes' properties
set(gca, 'FontName', 'Calibri','FontSize',12)

% Plot the results
time_period = 2023:2033+extra;
       
% Modify the fillArea function to include an invisible marker plot
fillArea = @(p1, p2, color) ...
    plotFillAndMarker(time_period, debt_path_success(:, p1)', debt_path_success(:, p2)', color);

% New function to plot fill and invisible marker
function h = plotFillAndMarker(x, y1, y2, color)
    fill([x, fliplr(x)], [y1, fliplr(y2)], color, 'LineStyle', 'none'); % Fills the area between curves    
    % Plots visible markers outside the plot area for legend purposes
    h = plot(nan, nan, 'o', 'MarkerSize', 10, 'MarkerEdgeColor', color, 'MarkerFaceColor', color);
end


% Fill areas for different percentile ranges
% % VTV colors
h1 = fillArea(1, 9, [153/255 171/255 191/255]); % 10-90th percentile, lightest blue
h2 = fillArea(2, 8, [102/255 128/255 159/255]); % 20-80th percentile, intermediate blue
h3 = fillArea(3, 7, [51/255 86/255 127/255]); % 30-70th percentile, darker blue 
h4 = fillArea(4, 6, [0/255 44/255 95/255]); % 40-60th percentile, darkest blue 

% VTV colors
% fillArea(1, 9, [204/255 213/255 223/255]); % 10-90th percentile, lightest blue '#CCD5DF'
% fillArea(2, 8, [153/255 171/255 191/255]); % 20-80th percentile, intermediate blue '#99ABBF'
% fillArea(3, 7, [102/255 128/255 159/255]); % 30-70th percentile, darker blue '#66809F'
% fillArea(4, 6, [51/255 86/255 127/255]); % 40-60th percentile, darkest blue '#33567F'
% % Gray colors
% fillArea(1, 9, [0.9 0.9 0.9]); % 10-90th percentile, lightest grey
% fillArea(2, 8, [0.7 0.7 0.7]); % 20-80th percentile, intermediate grey
% fillArea(3, 7, [0.5 0.5 0.5]); % 30-70th percentile, darker grey
% fillArea(4, 6, [0.3 0.3 0.3]); % 40-60th percentile, darkest grey

% Add a red horizontal line at the year 2025 and 2028 
yLimits = get(gca, 'ylim'); % Get the current y-axis limits
% VTV red
h5 = line([2025 2025], yLimits, 'Color','#fdb84a', 'LineStyle', '-', 'LineWidth', 1);
h6 = line([2028+extra 2028+extra], yLimits, 'Color','#fdb84a', 'LineStyle', '--', 'LineWidth', 1.5);
% regular red
% line([2024 2024], yLimits, 'Color', 'red', 'LineStyle', '-');
% line([2028+extra 2028+extra], yLimits, 'Color', 'red', 'LineStyle', '--');

% Plot the median as a VTV blue line
h7 = plot(time_period, debt_path_success(:, 5), 'Color',' #ff6875', 'LineWidth', 2,'marker','*'); % 50th percentile, black line
% Plot the median as a black line
%plot(time_period, debt_path_success(:, 5), 'k', 'LineWidth', 2,'marker','*'); % 50th percentile, black line

% Plot mean value from adjustment scenario
h8 = plot(time_period,debtPaths(1:horizon,stochOptimalIndex));
% Set y-axis limits
%ylim([55 85]);

% plot safeguard debt path in the figure
%plot(time_period,D_safeguard(1:horizon,debtSustOptimalIndex), 'Color',' black', 'LineWidth', 2,'marker','*');

% convert number to string with space
formatted_simulations = formatWithSpaces(nbr_sim_paths);

if language == 1 % English
    % Customize plot
    xlabel('Year','FontName', 'Calibri');
    ylabel('Debt-to-GDP, %','FontName', 'Calibri');

    if stochOptimalIndex ~= 0
        titleStr = sprintf('%d%% of the Debt Paths Declining - Adjustment %.2f pp. a year', plausibility*10, optimal_stoch_a);
        title(titleStr,'FontName', 'Calibri');
    else
        title(sprintf('%d%% of the Debt Paths Declining - Adjustment Plan Not Found', plausibility*10));
    end


    subtitle(sprintf('%d-year adjustment period (%s simulations)', adjustmentPeriods, formatted_simulations));
    legend([h8 h7, h5, h6, h4, h3, h2, h1],{'Mean','Median','Start of Adjustment Plan',...
        'End of Adjustment Plan','40th - 60th Percentile','30th - 70th Percentile',...
        '20th - 80th Percentile','10th - 90th Percentile'}, ...
        'Location','eastoutside','FontName', 'Calibri');
    legend('boxoff')
    %grid on;

    % Set the figure size
    set(gcf, 'Position', [200 200 1.3*FigSize FigSize]);
    
if plausibility == 7
    print(sprintf('DebtFanChart70_%s', methodName), '-dpng', '-r300', '-cmyk');
elseif plausibility == 8
    print(sprintf('DebtFanChart80_%s', methodName), '-dpng', '-r300', '-cmyk');
elseif plausibility == 9
    print(sprintf('DebtFanChart90_%s', methodName), '-dpng', '-r300', '-cmyk');
end


elseif language == 2 % Suomi
    % Customize plot
    xlabel('Vuosi','FontName', 'Calibri');
    ylabel('Velkasuhde, %','FontName', 'Calibri');

    if stochOptimalIndex ~= 0
        titleStr = sprintf('%d%% velkaurista laskevia - vuosittainen sopeutus %.2f %%-yksikköä', plausibility*10, optimal_stoch_a);
        title(titleStr,'FontName', 'Calibri');
    else
        title(sprintf('%d%% velkaurista laskevia - vuosittaista sopeutusta ei löydy', plausibility*10));
    end
    
    subtitle(sprintf('%d vuoden sopeutusjakso (%s simulaatiota)', adjustmentPeriods, formatted_simulations));
    legend([h8 h7, h5, h6, h4, h3, h2, h1],{'Keskiarvo','Mediaani','Sopeutusjakso alkaa',...
        'Sopeutusjakso päättyy','4. - 6. desiili','3. - 7. desiili',...
        '2. - 8. desiili','1. - 9. desiili'}, ...
        'Location','eastoutside','FontName', 'Calibri');
    legend('boxoff')
    %grid on;

    % Set the figure size
    set(gcf, 'Position', [200 200 1.3*FigSize FigSize]);
    
if plausibility == 7
    print(sprintf('Velkaviuhka70_%s', methodName), '-dpng', '-r300', '-cmyk');
elseif plausibility == 8
    print(sprintf('Velkaviuhka80_%s', methodName), '-dpng', '-r300', '-cmyk');
elseif plausibility == 9
    print(sprintf('Velkaviuhka90_%s', methodName), '-dpng', '-r300', '-cmyk');
end


end

end
