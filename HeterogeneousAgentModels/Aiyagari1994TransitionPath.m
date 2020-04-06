% Example of computing a general eqm transition path for the model of Aiyagari (1994).
%
% These codes set up and solve the Aiyagari (1994) model for a given
% parametrization. They then show how to solve for the general equilibrium
% transition path in reposonse to a 'surprise' one off change in the
% parameter beta (the time discount parameter).
%
% VFI Toolkit automatically detects hardware (GPU? Number of CPUs?) and
% sets defaults accordingly. It will run without a GPU, but slowly. It is
% indended for use with GPU.

%% Set some basic variables

n_k=2^7;%2^9;
n_s=15; %21;
n_p=0; % Normally you will want n_p=0, setting a non-zero value here activates the use of a grid on prices.

%Parameters
Params.beta=0.96;
Params.alpha=0.36; % This is actually redundant as declare this below when looking at initial and final eqm
Params.delta=0.08;
Params.mu=3;
Params.sigma=0.2;
Params.rho=0.6;

Params.q=3; %Footnote 33 of Aiyagari(1993WP, pg 25) implicitly says that he uses q=3

% Params has been created as a structure. You can create the individual
% parameters from the structure by running the following command
CreateIndividualParams(Params)

%% Since this example is intended to show working of transtion paths, make it verbose (print output)
transpathoptions.verbose=1;

%% Set up the exogenous shock process
%Create markov process for the exogenous labour productivity, l.
% Aiyagari (1994) uses 11 states (n_s=11), and footnote 33 of Aiyagari(1993WP, pg 25) implicitly says that he uses q=3.
[s_grid, pi_s]=TauchenMethod(0,(Params.sigma^2)*(1-Params.rho^2),Params.rho,n_s,Params.q);

[s_mean,s_variance,s_corr,~]=MarkovChainMoments(s_grid,pi_s);
s_grid=exp(s_grid);
%Get some info on the markov process
[Expectation_l,~,~,~]=MarkovChainMoments(s_grid,pi_s); %Since l is exogenous, this will be it's eqm value 
%Note: Aiyagari (1994) actually then normalizes l by dividing it by
%Expectation_l (so that the resulting process has expectaion equal to 1
%(see Aiyagari (1993WP), footnote 33 pg 25-26).
%The following three lines do just this.
s_grid=s_grid./Expectation_l;
[Expectation_l,~,~,~]=MarkovChainMoments(s_grid,pi_s);

%% Grids

%In the absence of idiosyncratic risk, the steady state equilibrium is given by
r_ss=1/Params.beta-1;
K_ss=((r_ss+Params.delta)/Params.alpha)^(1/(Params.alpha-1)); %The steady state capital in the absence of aggregate uncertainty.

% Set grid for asset holdings
%Aiyagari uses 25 points, but with a piecewise-linear approx. see Aiyagari (1993WP, pg 28).
%His grid is not directly on k, but implicitly his k grid runs from zero up
%to k_max, where k_max is given by f(k_max,1)=delta*k_max
%k_max=delta^(1/(alpha-1));
%Doing this k_max is slightly less than 10*K_ss. But if I use this as the upper limit on
%the grid the results are wrong (in that increasing this to 15 or 20*K_ss
%gives different results). It might be that Aiyagari gets away with this
%due to his use of piecewise-linear approximation (ie. that policy fn is
%almost linear in this region anyway).
nk1=floor(n_k/3); nk2=floor(n_k/3); nk3=n_k-nk1-nk2;
k_grid=sort([linspace(0,K_ss,nk1),linspace(K_ss+0.0001,3*K_ss,nk2),linspace(3*K_ss+0.0001,15*K_ss,nk3)]');

%Bring model into the notational conventions used by the toolkit
d_grid=0; %There is no d variable
a_grid=k_grid;
%pi_s;
%s_grid

n_d=0;
n_a=n_k;
%n_s

%Create descriptions of SS values as functions of d_grid, a_grid, s_grid &
%pi_s (used to calculate the integral across the SS dist fn of whatever
%functions you define here)
FnsToEvaluateParamNames(1).Names={};
FnsToEvaluateFn_1 = @(aprime_val,a_val,s_val) a_val; %We just want the aggregate assets (which is this periods state)
FnsToEvaluate={FnsToEvaluateFn_1};

%Now define the functions for the General Equilibrium conditions
    %Should be written as LHS of general eqm eqn minus RHS, so that 
    %the closer the value given by the function is to zero, the closer 
    %the general eqm condition is to holding.
GeneralEqmEqnParamNames(1).Names={'alpha','delta'};
GeneralEqmEqn_1 = @(AggVars,p,alpha,delta) p-(alpha*(AggVars^(alpha-1))*(Expectation_l^(1-alpha))-delta); %The requirement that the interest rate corresponds to the agg capital level
GeneralEqmEqns={GeneralEqmEqn_1};

disp('sizes')
n_a
n_s
n_p

%%
DiscountFactorParamNames={'beta'};

ReturnFn=@(aprime_val, a_val, s_val,alpha,delta,mu,r) Aiyagari1994_ReturnFn(aprime_val, a_val, s_val,alpha,delta,mu,r);
ReturnFnParamNames={'alpha','delta','mu','r'}; %It is important that these are in same order as they appear in 'Aiyagari1994_ReturnFn'

%%

%Use the toolkit to find the equilibrium price index
GEPriceParamNames={'r'};
%Set initial value for interest rates (Aiyagari proves that with idiosyncratic
%uncertainty, the eqm interest rate is limited above by it's steady state value
%without idiosyncratic uncertainty, that is that r<r_ss).
Params.r=0.04;

%% Compute the initial general equilibrium
Params.alpha=0.36;

disp('Calculating price vector corresponding to the initial stationary eqm')
[p_eqm_init,~,GeneralEqmCondition]=HeteroAgentStationaryEqm_Case1(n_d, n_a, n_s, n_p, pi_s, d_grid, a_grid, s_grid, ReturnFn, FnsToEvaluate, GeneralEqmEqns, Params, DiscountFactorParamNames, ReturnFnParamNames, FnsToEvaluateParamNames, GeneralEqmEqnParamNames, GEPriceParamNames);

p_eqm_init

% For the transition path we will need the initial agents distribution
Params.r=p_eqm_init.r;
[~,Policy_init]=ValueFnIter_Case1(n_d,n_a,n_s,d_grid,a_grid,s_grid, pi_s, ReturnFn,Params, DiscountFactorParamNames,ReturnFnParamNames);
StationaryDist_init=StationaryDist_Case1(Policy_init,n_d,n_a,n_s,pi_s);

% Double check some things
AggVars_init=EvalFnOnAgentDist_AggVars_Case1(StationaryDist_init, Policy_init, FnsToEvaluate, Params, FnsToEvaluateParamNames, n_d, n_a, n_s, d_grid, a_grid, s_grid);
GeneralEqmCondition_init=real(GeneralEqmConditions_Case1(AggVars_init,[p_eqm_init.r], GeneralEqmEqns, Params, GeneralEqmEqnParamNames));

[GeneralEqmCondition, GeneralEqmCondition_init]

%% Compute the final general equilbrium
Params.alpha=0.4;

% Note: if the change in parameters affected pi_s this would need to be recalculated here.

disp('Calculating price vector corresponding to the final stationary eqm')
[p_eqm_final,~,GeneralEqmCondition]=HeteroAgentStationaryEqm_Case1(n_d, n_a, n_s, n_p, pi_s, d_grid, a_grid, s_grid, ReturnFn, FnsToEvaluate, GeneralEqmEqns, Params, DiscountFactorParamNames, ReturnFnParamNames, FnsToEvaluateParamNames, GeneralEqmEqnParamNames, GEPriceParamNames);

p_eqm_final

% For the transition path we will need the final value function
Params.r=p_eqm_final.r;
[V_final,Policy_final]=ValueFnIter_Case1(n_d,n_a,n_s,d_grid,a_grid,s_grid, pi_s, ReturnFn,Params, DiscountFactorParamNames,ReturnFnParamNames);

StationaryDist_final=StationaryDist_Case1(Policy_final,n_d,n_a,n_s,pi_s);
AggVars_final=EvalFnOnAgentDist_AggVars_Case1(StationaryDist_final, Policy_final, FnsToEvaluate, Params, FnsToEvaluateParamNames, n_d, n_a, n_s, d_grid, a_grid, s_grid);
GeneralEqmCondition_final=real(GeneralEqmConditions_Case1(AggVars_final,p_eqm_final.r, GeneralEqmEqns, Params, GeneralEqmEqnParamNames));

[GeneralEqmCondition, GeneralEqmCondition_final]

% % Alternatively, you could use the p_grid option
% n_p=101; p_grid=linspace(p_eqm_final.r-0.01,p_eqm_final.r+0.01,n_p); heteroagentoptions.pgrid=p_grid;
% [p_eqm2,p_eqm_index2,GeneralEqmConditionVec2]=HeteroAgentStationaryEqm_Case1(n_d, n_a, n_s, n_p, pi_s, d_grid, a_grid, s_grid, ReturnFn, FnsToEvaluate, GeneralEqmEqns, Params, DiscountFactorParamNames, ReturnFnParamNames, FnsToEvaluateParamNames, GeneralEqmEqnParamNames, GEPriceParamNames,heteroagentoptions);
% p_grid2=linspace(p_grid(p_eqm_index2-5),p_grid(p_eqm_index2+5),n_p); heteroagentoptions.pgrid=p_grid2;
% [p_eqm3,p_eqm_index3,GeneralEqmConditionVec3]=HeteroAgentStationaryEqm_Case1(n_d, n_a, n_s, n_p, pi_s, d_grid, a_grid, s_grid, ReturnFn, FnsToEvaluate, GeneralEqmEqns, Params, DiscountFactorParamNames, ReturnFnParamNames, FnsToEvaluateParamNames, GeneralEqmEqnParamNames, GEPriceParamNames,heteroagentoptions);
% 
% [p_eqm_final.r, p_eqm2.r, p_eqm3.r]

% surf(k_grid*ones(1,n_s),ones(n_a,1)*s_grid',V_final)

%% Compute the transition path
% For this we need the following extra objects: PricePathOld, PriceParamNames, ParamPath, ParamPathNames, T, V_final, StationaryDist_init
% (already calculated V_final & StationaryDist_init above)

% Number of time periods to allow for the transition (if you set T too low
% it will cause problems, too high just means run-time will be longer).
T=100

% We want to look at a one off unanticipated change of beta. ParamPath & PathParamNames are thus given by
ParamPath.alpha=0.4*ones(T,1); % For each parameter that changes value, ParamPath is matrix of size T-by-1
% (the way ParamPath is set is designed to allow for a series of changes in the parameters)
% ParamPathNames={'alpha'};

% We need to give an initial guess for the price path on interest rates
PricePath0.r=[linspace(p_eqm_init.r, p_eqm_final.r, floor(T/2))'; p_eqm_final.r*ones(T-floor(T/2),1)]; % For each price, PricePath0 is matrix of size T-by-1
% PricePathNames={'r'};

% Rewrite the General Eqm conditions as rules for updating the price
transpathoptions.GEnewprice=1; % If you do not do this the codes can still solve, but take much longer as they must figure out an updating rule for themselves.
GeneralEqmEqnParamNames(1).Names={'alpha','delta'};
GeneralEqmEqn_1 = @(AggVars,p,alpha,delta) (alpha*(AggVars^(alpha-1))*(Expectation_l^(1-alpha))-delta); %The interest rate that corresponds to the marginal product of capital
GeneralEqmEqns={GeneralEqmEqn_1};

% [transpathoptions.GEnewprice=1 means that the GeneralEqmEqns should be
% expressed as how to generate a new guess for the price based on the
% current guess; transpathoptions.GEnewprice=0 means the GeneralEqmEqns
% should be expressed as for the standard general eqm conditions, namely
% equations that take the value of 0 in general eqm.]

% Now just run the TransitionPath_Case1 command (all of the other inputs
% are things we had already had to define to be able to solve for the
% initial and final equilibria)
transpathoptions.weightscheme=1
transpathoptions.verbose=1
PricePathNew=TransitionPath_Case1(PricePath0, ParamPath, T, V_final, StationaryDist_init, n_d, n_a, n_s, pi_s, d_grid,a_grid,s_grid, ReturnFn, FnsToEvaluate, GeneralEqmEqns, Params, DiscountFactorParamNames, ReturnFnParamNames, FnsToEvaluateParamNames, GeneralEqmEqnParamNames,transpathoptions);



