

%% Define parameters in a structure for DSA5v.m
params = struct;
params.adjustmentPeriods = 7;
params.sfa_method = -1;
params.apply_debt_safeguard = 1;
params.apply_deficit_benchmark =1;
params.apply_deficit_safeguard = 1;
params.plotting = 0;
params.power = 3;
params.plausibility = 7;
params.language = 1;
params.stoch_method = 1;
params.saveFlag = 0;


%% PARAMETER SELECTION OPTIONS

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
        
        
%% Call the function with the parameter structure
runDsaModel5(params);

