% Function to project the debt for a given a
function [debt_out,g_out,drgdp_out,iir_out,pb_out,spb_out,ob_out,sb_out,rgdp_out]=project_debt5v(...
    scenario, adjustment, iir, potgdp, og, epsilon,m,dcoa,dprop,sfa,inflation,rgdp_initial,debt_initial,...
    alpha_initial,beta_initial,spb,i_st,i_lt,m_lt,pb,ob,sb,stoch_sim,g_sim,pb_sim,iir_sim,adj_periods)




%%%% ADD ADJUSTMENT MUST BE > 0 because the routine is based on
%%%% adjustment!!!!!!!!!!!!!

%% check lower SPB



        % THIS FUNCTION CALCULATES PROJECTED DEBT PATH GIVEN PARAME %
        
        % SET SCENARIO TO RUN
        % 1) ADJUSTMENT
        % 2) LOWER SPB
        % 3) ADVERSE r-g
        % 4) FINANCIAL STRESS
        
        % STOCHASTIC SIMULATIONS
        % If no simulations required, set stoch_sim = 1
        % and set g_sim,pb_sim,iir_sim to zero
        % 1) NORMAL SHOCKS
        % 2) BLOCK BOOTSTRAP
        % 
        
        % FUNCTION OUTPUTS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % debt: debt-to-gdp projection
        % g: nominal growth of gdp
        % drgdp: real gdp growth
        % iir_out: implicit interest rate output
        % pb_out: primary balance output
        % spb_out: structural primary balance output
        % ob_out: overall balance output
        % sb_out: structural balance output
        % rgdp_out: real gdp level
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        % FUNCTION INPUTS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % scenario: select scenario
        % stoch_sim: select stochastic simulation
        % adjustment: adjustment per period (in spb terms)
        % iir: implicit interest rate (percent)
        % potgdp: potential output (in MRD euros)
        % og: output gap (percent of potGDP)
        % epsilon: elasticity of budget balance
        % phi: fiscal multiplier on impact
        % dcoa: change in cost of ageing relative to end of adjustment
        % dprop: change in property income relative to end of adjustment
        % sfa: stock-flow adjustment
        % inflation: price inflation
        % debt_initial: initial level of debt-to-gdp in t
        % spb: COM forecasted spb up to period t+2 (percent of nom GDP)
        % rgdp: COM forecasted real gdp level up to period t+2 (in MRD euros)
        % ngdp: COM forecasted nominal gdp level up to period t+2 (in MRD euros)
        % debt_st: short term debt (in MRD euros)
        % debt_total: total debt (in MRD euros)
        % debt_ltn: new long term debt (in MRD euros)
        % debt_lt: long term debt (in MRD euros)
        % i_st: short term market interest rate
        % i_lt: long term market interset rate
        % m_lt : share of long term debt maturing yearly
        % pb: COM forecasted pb up to period t+2 (percent of nom GDP)
        % ob: COM forecasted overall balance up to period t+2 (percent of nom GDP)
        % sb: COM forecasted structural balance up to period t+2 (percent of nom GDP)
        % g_sim: simulated nominal gdp growth shock/draw for stochastic analysis
        % pb_sim: simulated primary balance shock/draw for stochastic analysis
        % iir_sim: simulated implicit interest rate shock/draw for stochastic analysis
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
%% Housekeeping        
       
    % Create shells
    periods = length(og); % total number of periods
    rgdp = NaN(periods, 1); % real gdp
    drgdp = NaN(periods, 1); % real gdp growth
    dpotgdp= NaN(periods, 1); % potential gdp growth
    g = NaN(periods, 1);     % nominal gdp growth
    debt = NaN(periods, 1);  % debt-to-gdp ratio
    alpha = NaN(periods, 1); % share of new short term debt / total debt
    beta = NaN(periods, 1);  % share of new long term debt / total lt debt
    iir_lt = NaN(periods, 1);% long term implied interest rate
    interest = NaN(periods, 1);        % interest payments (pp. of gdp)
    growth_effect = NaN(periods, 1);        % real gdp growth effect (pp. of gdp)
    inflation_effect = NaN(periods, 1);        % inflation effect (pp. of gdp)
    ob_out = NaN(periods, 1);             % overall balance
    sb_out = NaN(periods, 1);             % structural balance
    spb_out = NaN(periods, 1);       % shell for spb output vector
    d_ltr = NaN(periods, 1); % rolled over long term debt
    d_str = NaN(periods, 1); % rolled over short term debt
    d_ltn = NaN(periods, 1); % new long term debt
    d_stn = NaN(periods, 1); % new short term debt
    d_o = NaN(periods, 1); % outstanding debt
    debt_increasing = NaN(periods, 1); % aux var to identify increasing debt
    debt_rolled = NaN(periods, 1); % aux var to identify rolled over debt
    
    adjustment_start_t = 3; % adjustment plan start period
    before_adjustment_start_t = adjustment_start_t - 1; % the period before plan starts
    adjustment_end_t = before_adjustment_start_t + adj_periods; % adjustment plan end period
    review_start_t = adjustment_end_t + 1; % review period start
    og_closing_factor = NaN(periods,1); % output gap closing factor
    
    % Parameters
    %theta_st = 0.10829; % short-term share in total debt, average of 3 previous years
    theta_lt = 0.89170; % long-term share in total debt, average of 3 previous years
    SPB_shock = 0.25;        % lower SPB shock in the first step
    SPB_shock2 = 2*0.25;     % lower SPB shock in the second step
    interest_rate_shock = 0.5; % interest rate shock used in scenario 3&4
    gdp_shock = zeros(periods, 1); % gdp shock in adverse r-g scenario 3
    debt(1) = debt_initial;  % initial debt-to-gdp ratio in 2023
    alpha(1) = alpha_initial;  % initial share of short-term debt in total debt 2023
    beta(1) = beta_initial;  % initial share of new long-term debt in long-term debt 2023
    M = 0.75; % scalar fiscal multiplier
    if scenario == 2 % modify OG closing in lower SPB scenario
        
        % OG closing factor remains at 2/3 also during 2 shocking periods
        og_closing_factor(adjustment_start_t + 1: review_start_t + 2) = 2/3; % gap closes 2/3 compared to t-1
        og_closing_factor(review_start_t + 3) = 0.5; % gap closes 1/2 compared to t-1
        og_closing_factor(review_start_t + 4:end) = 0; % gap is closed
        
    else % standard OG closing assumption
        
        og_closing_factor(adjustment_start_t + 1: review_start_t) = 2/3; % gap closes 2/3 compared to t-1
        og_closing_factor(review_start_t + 1) = 0.5; % gap closes 1/2 compared to t-1
        og_closing_factor(review_start_t + 2:end) = 0; % gap is closed
        
    end
    
    if scenario == 3 % modify potential gdp in adverse r-g scenario
        
        %baseline pot gdp
        baseline_potgdp = potgdp;
        % 0.5 percentage lower gdp from monitoring period on
        gdp_shock(review_start_t:end) = 0.005*ones(periods - adjustment_end_t,1);
        
        for t = before_adjustment_start_t:periods
            % baseline potential gdp growth
            dpotgdp(t) =  ((baseline_potgdp(t) - baseline_potgdp(t-1)) / baseline_potgdp(t-1));
            
            %lower potential gdp level by 0.5% from the monitor period on
            potgdp(t) = (1 + dpotgdp(t) - gdp_shock(t) ) *  potgdp(t-1);
        end
    end
   
%% MAIN LOOP %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

rgdp(1) = (1 + og(1)/100) * potgdp(1); %real gdp level in period 1

drgdp(1) =  ((rgdp(1) - rgdp_initial) / rgdp_initial); % real gdp growth

% nominal gdp growth (adjustment, lower SPB or financial stress scenario)
g(1) = (1 + drgdp(1)) * (1 + inflation(1)) - 1; % nominal gdp growth

% start loop from 2nd period
for t = before_adjustment_start_t:periods 


    % Calculate real gdp taking into account possible adjustment
    if t <= adjustment_start_t 

        % real gdp level without adjustment
        rgdp(t) = potgdp(t) * (1 + og(t)/100); 

        % real gdp growth considering adjustment
        drgdp(t) =  ((rgdp(t) - rgdp(t-1)) / rgdp(t-1)) - (m(t)*adjustment/100);        

    % take also into account the assumption that the OG closes gradually
    else        
        % real gdp level with OG closes and adjustment
        rgdp(t) = potgdp(t) * (1 + og_closing_factor(t)*og(t-1)/100) - rgdp(t-1)*(m(t)*adjustment/100);    
        
        % real gdp growth
        drgdp(t) =  ((rgdp(t) - rgdp(t-1)) / rgdp(t-1));        
    end
    
    % take into account stimulus from SPB shock in lower SPB scenario
    if scenario == 2 && (t == review_start_t || t == review_start_t + 1) 
    
        rgdp(t) = rgdp(t) + (rgdp(t-1) * M * SPB_shock);
    end
    
    
    % update real gdp level
    rgdp(t) = (1 + drgdp(t)) * rgdp(t-1); 

    % update OG
    og(t) = 100 * ((rgdp(t)/potgdp(t)) - 1);

    % nominal gdp growth
    g(t) = (1 + drgdp(t)) * (1 + inflation(t)) - 1; 
    


       
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % PRE-ADJUSTMENT PERIOD 

    % calculate value for 2024 NOT NEEDED
    if t <= before_adjustment_start_t 
        pb(t) = spb(t) + epsilon*(og(t)); %primary balance


    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    
    % ADJUSTMENT PERIOD 

    % calculate values for adjustment period
    elseif t >= adjustment_start_t  && t <= adjustment_end_t 
        spb(t) = (t-before_adjustment_start_t)*adjustment + spb(before_adjustment_start_t); %adjustment + initial SPB level
        pb(t) = spb(t) + epsilon*og(t) - dcoa(t) - dprop(t); %spb + correction for cycle


    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%   
    % POST-ADJUSTMENT PERIOD

    % calculate values for post-adjustment period given scenario selected

        %%%%%%%%%%%%%%%%%%%%%
        % ADJUSTMENT scenario
    elseif t >= review_start_t &&  scenario == 1 % PB post-adjustment period
        % age-adjusted primary balance
        pb(t) = (adj_periods)*adjustment + spb(before_adjustment_start_t) + epsilon*og(t) - dcoa(t) - dprop(t);
        spb(t) = (adj_periods)*adjustment + spb(before_adjustment_start_t); %save current period t spb

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % LOWER SPB scenario (step 1)
    elseif t == review_start_t && scenario == 2 % 0.25% lower SPB*
        % age-adjusted primary balance
        pb(t) = (adj_periods)*adjustment + spb(before_adjustment_start_t) -SPB_shock + epsilon*og(t) - dcoa(t) - dprop(t);
        spb(t) = (adj_periods)*adjustment + spb(before_adjustment_start_t) -SPB_shock; %save current period t spb 
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % LOWER SPB scenario (step 2)
    elseif t > review_start_t  && scenario == 2 % permanently 0.5% lower SPB*
        % age-adjusted primary balance
        pb(t) = (adj_periods)*adjustment + spb(before_adjustment_start_t)-SPB_shock2 + epsilon*og(t) - dcoa(t) - dprop(t);
        spb(t) =  (adj_periods)*adjustment + spb(before_adjustment_start_t) -SPB_shock2; %save current period t spb

        %%%%%%%%%%%%%%%%%%%%%%
        % ADVERSE r-g scenario     
    elseif t >= review_start_t && scenario == 3 % permanently +0.5% i_st/i_lt
        i_lt(t) = i_lt(t) + interest_rate_shock; % higher short term interest rate 
        i_st(t) = i_st(t) + interest_rate_shock; % higher long term interest rate
        % age-adjusted primary balance
        pb(t) = (adj_periods)*adjustment + spb(before_adjustment_start_t) + epsilon*og(t) - dcoa(t) - dprop(t);
        spb(t) = (adj_periods)*adjustment + spb(before_adjustment_start_t); %save current period t spb


        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % FINANCIAL STRESS scenario (step 1)  
        
    elseif t == review_start_t && scenario == 4 % temporarely +1% i_st/i_lt
        i_lt(t) = i_lt(t) + 2*interest_rate_shock; % higher short term interest rate 
        i_st(t) = i_st(t) + 2*interest_rate_shock; % higher long term interest rate
        % age-adjusted primary balance
        pb(t) = (adj_periods)*adjustment + spb(before_adjustment_start_t) + epsilon*og(t) - dcoa(t) - dprop(t);
        spb(t) = (adj_periods)*adjustment + spb(before_adjustment_start_t); %save current period t spb

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % FINANCIAL STRESS scenario (step 2)  

    elseif t > review_start_t && scenario == 4
        % age-adjusted primary balance
        pb(t) = (adj_periods)*adjustment + spb(before_adjustment_start_t) + epsilon*og(t) - dcoa(t) - dprop(t);
        spb(t) = (adj_periods)*adjustment + spb(before_adjustment_start_t); %save current period t spb

    else
        disp('No scenario selected. Set scenario 1-4');
        return;
    end


%% Calculate implied interest rates     

    % Calculate iir_lt (use EC forecast for iir)
    if t <= adjustment_start_t 
        iir_lt(t) = (iir(t) - alpha(t-1) * i_st(t)) / (1 - alpha(t-1)); %eq.3 (p.133)
    else
        % Use DSM 2023 Annex A3.2 formulation after 
        iir_lt(t) = beta(t-1) * i_lt(t) + (1 - beta(t-1)) * iir_lt(t-1);    %eq. 6 (p.134)
        iir(t) = alpha(t-1) * i_st(t) + (1 - alpha(t-1)) * iir_lt(t);       %eq. 3' (p.134)
    end


%% Update debt drivers to account possible stochastic shocks

    if stoch_sim == 1 || stoch_sim == 2
    % update debt drivers with stochastic shocks
    g(t) = g(t) + g_sim(t);
    pb(t) = pb(t) + pb_sim(t);
    iir(t) = iir(t) + iir_sim(t);

    else
        disp('Stochastic simulation method not set.');
        return;
    end
            
      
%% DEBT DYNAMIC EQUATION %%

% Main equation to project debt
debt(t) = debt(t-1) * ((1 + iir(t)/100) / (1 + g(t))) - pb(t) + sfa(t);


% Decompose the debt dynamics as pp. of gdp (DSM2023 Annex A3)

% interest rate effect
interest(t) = debt(t-1) * ( (iir(t)/100) / (1 + g(t)) );

%real gdp growth effect
growth_effect(t) = -debt(t-1) * ((drgdp(t)) / (1 + g(t)));

%inflation effect
inflation_effect(t) = -debt(t-1) * (inflation(t)*(1 + drgdp(t)) / (1 + g(t)) );


%% Calculate debt structure

% track debt change
debt_increasing(t) = debt(t) - ( debt(t-1) / (1 + g(t)) );

% track debt rolling over though debt is decreasing
debt_rolled(t) = abs(debt_increasing(t)) - ...
                ( debt(t-1) * (alpha(t-1) + (1 - alpha(t-1))*m_lt(t))) / (1 + g(t));
               
% debt is zero
if debt == 0
    
    %long-term rolled over debt ratio
    d_ltr(t) = 0;

    %short-term rolled over debt ratio
    d_str(t) = 0;

    %long-term new debt ratio
    d_ltn(t) = 0;

    %short term new debt ratio
    d_stn(t) = 0;

    % outstanding debt ratio
    d_o(t) = 0;

    % short term share
    alpha(t) = 0;

    % new long term debt in long term debt
    beta(t) = 0;
    
% debt increasing
elseif debt_increasing(t) > 0
    
    %long-term rolled over debt ratio
    d_ltr(t) = (m_lt(t) * (1 - alpha(t-1)) * debt(t-1)) * (1 + g(t))^-1;

    %short-term rolled over debt ratio
    d_str(t) = alpha(t-1) * debt(t-1) * (1 + g(t))^-1;

    %long-term new debt ratio
    d_ltn(t) = theta_lt * (debt(t) - (debt(t-1) / (1 + g(t))));

    %short term new debt ratio
    d_stn(t) = (1 - theta_lt) * (debt(t) - (debt(t-1) / (1 + g(t))));

    % outstanding debt ratio
    d_o(t) = (debt(t-1)/(1 + g(t))) - d_str(t) - d_ltr(t) ;

    % short term share
    alpha(t) = (d_str(t) + d_stn(t) ) / debt(t);

    % new long term debt in long term debt
    beta(t) = (d_ltr(t) + d_ltn(t) ) / (d_ltr(t) + d_ltn(t) + d_o(t));
    
% debt decreasing and rolled over
elseif debt_increasing(t) <= 0 && debt_rolled(t) < 0
    
    % long-term rolled over 
    term1 = (1 - alpha(t-1)) * m_lt(t) * debt(t-1) * (1 + g(t))^-1;
    %short-term rolled over 
    term2 = alpha(t-1) * debt(t-1) * (1 + g(t))^-1;
    %absolute debt
    term3 = abs(debt_increasing(t));
    
    
    %long-term rolled over debt ratio
    d_ltr(t) = term1 * (1 - (term3/(term1 + term2)));

    %short-term rolled over debt ratio
    d_str(t) = term2 * (1 - (term3/(term1 + term2)));

    %long-term new debt ratio
    d_ltn(t) = 0;

    %short term new debt ratio
    d_stn(t) = 0;

    % outstanding debt ratio
    d_o(t) = debt(t-1)*(1 - alpha(t-1) - m_lt(t) * (1 - alpha(t-1))) / (1 + g(t));

    % short term share
    alpha(t) = (d_str(t) + d_stn(t) ) / debt(t);

    % new long term debt in long term debt
    beta(t) = (d_ltr(t) + d_ltn(t) ) / (d_ltr(t) + d_ltn(t) + d_o(t));

% debt decreasing and not rolled over
elseif debt_increasing(t) <= 0 && debt_rolled(t) >= 0
   
    %long-term rolled over debt ratio
    d_ltr(t) = 0;

    %short-term rolled over debt ratio
    d_str(t) = 0;

    %long-term new debt ratio
    d_ltn(t) = 0;

    %short term new debt ratio
    d_stn(t) = 0;

    % outstanding debt ratio
    d_o(t) = debt(t) ;

    % short term share
    alpha(t) = 0;

    % new long term debt in long term debt
    beta(t) = 1;
    
end

% update OB and SB from adjustment on
if t >= 3

    % calculate overall balance (3% deficit criteria)
    ob(t) = pb(t) - interest(t);

    %calculate structural balance (1.5% deficit resilience safeguard)
    sb(t) = spb(t) - interest(t);
end

end %main loop ends
    
%% Save output variables
debt_out = debt; 
g_out = g;          
rgdp_out = rgdp;
drgdp_out = drgdp;
iir_out = iir;
ob_out = ob;
pb_out = pb;
sb_out = sb;
spb_out = spb;
    
end