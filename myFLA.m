function [flaEquity] = myFLA(Instrument, totalWindowSize, windowLenght_iS, windowLength_ooS, moveInterval, graphics)
%% INPUT PARAMETER
% Instrument        = which data to load, e.g. 'EURUSD'
% totalWindowSize   = measured from the first data point, how much data
%                   should be taken into calculation for the consecutive walks.
%                   FLA stops when end of totalWindowSize is reached
% windowLenght_iS   = window length of data for in-sample optimization
% windowLength_ooS  = window length of data for out-of-sample backtest
% moveInterval      = number of years to shift (per walk)
% if graphics       == 1 plotting is activated
%--------------------------------------------------------------------------

%% CHECK FOR CORRECT INPUT

if graphics > 1
    error_graphics = 'Please check your input parameter, graphics must not be greater than 1'
    
elseif graphics < 0
    error_graphics = 'Please check your input parameter, graphics must not be less than 1'
    
else %no input error -> run code   
    
    %% INITIALIZE VECTORS/ARRAYS/VARIABLES
    % global to be available in all functions
    
    global startDate;
    global endDate;
    global open;
    global high;
    global low;
    global close;
    global dates;
    
    flaPL; % array with all generated PL
    flaEquity(1) = 100000; % Initial account balance
    
    % global currStartDate;
    % global currEndDate;
    % global priceData;
    
    %--------------------------------------------------------------------------
    
    %% DATA PREPARATION
    
    % read data
    [data txt] = xlsread(Instrument);
    
    % assign data - global to be available in all functions
    open = data(:,1);
    high = data(:,2);
    low = data(:,3);
    close = data(:,4);
    dates = datetime(txt(2:end,1));
    %--------------------------------------------------------------------------
    
    %% WALK FORWARD
    
    startDate = dates(1); % first available date in dataset
    endDate = startDate + totalWindowSize; % endDate = end of totalWindowSize
    
    %==================== MAJOR CALCULATION ===============================
    for date = startDate : moveInterval : endDate
        
        % run in-sample optimization
        runOptimizer_iS(1,2,3,4);
        
        % run out-of-sample backtest
        runBacktest_ooS(1,2);
        
        flaPL = vertcat(flaPL, ooS_pl); % merge new ooS_pl into final pl-array
        
    end
    %======================================================================
    
    % delete all zeros of PL array
    flaPL(find(flaPL == 0)) = [];
    
    % Calculate ooS EquityCurve from cleaned P&L data
    for ii = 2 : length(flaPL)
        flaEquity(ii) = flaEquity(ii-1) + flaPL(ii);
    end
    
    if (graphics)
        plot(flaEquity); % flaEquity = each ooS_equity combined
    end
    
end
end

function [optParam1, optParam2] = runOptimizer_iS(lowerLimit1, upperLimit1, lowerLimit2, upperLimit2, param1, param2)
%% INPUT PARAMETER

% lowerLimit1 = lower limit for optimization of parameter 1
% upperLimit1 = upper limit for optimization of parameter 1
% lowerLimit2 = lower limit for optimization of parameter 2
% upperLimit2 = upper limit for optimization of parameter 2
% param1 = input parameter 1 for the trading strategy
% param2 = input parameter 2 for the trading strategy

% Set current date borders
currStartDate = date; % date = input from the for-loop
currEndDate = date + windowLenght_iS; % window-length = input from the FLA-function call

% Initialize arrays with dimensions according to input limits
iS_pdRatio = cell(upperLimit1 - lowerLimit1, upperLimit2- lowerLimit2);
iS_pl = cell(upperLimit1 - lowerLimit1, upperLimit2- lowerLimit2);
iS_totalPL = cell(upperLimit1 - lowerLimit1, upperLimit2- lowerLimit2);

currData = close(currStartDate : currEndDate, 1); %set current data set with date-borders

% cicle through all parameter combinations and create a heatmap
for ii = lowerLimit1 : upperLimit1 %cicle through each column
    for jj = lowerLimit2 : upperLimit2 %cicle through each row
        
        trade_strategy(supertrend, ii, jj, currData); %trade on current data set, pd_ratio, pl, totalPL are returned and saved for each walk
        % save returned values in arrays
        iS_pdRatio(ii,jj) = pdRatio;
        iS_pl(ii,jj) = pl;
        iS_totalPL(ii,jj) = totalPL;
        
    end
end

% create a heatmap of data matrix with returned curr_pdRatio
pd_heatmap = heatmap(curr_pdRatio,xvar,yvar);

if (graphics)
    plot(pd_heatmap); % plot each heatmap
end

% detect max value of pdRatio array and save the position indices
% of it as optParams
[optParam1, optParam2] = max(curr_pdRatio);

end

function [ooS_equity] = runBacktest_ooS(optParam1, optParam2)
%% INPUT PARAMETER

% optParam1 =
% optParam2 =

% Set current date borders
currStartDate = date + windowLenght_iS;
currEndDate = date + windowLenght_iS + windowLength_ooS;

currData = close(currStartDate : currEndDate, 1); %set current data set with date-borders

% Trade strategy with optimal parameters calculated in the iS-test
trade_strategy(optParam1, optParam2, currData); %trade on current data set, pd_ratio, pl, totalPL are returned and saved for each walk

% save returned values in arrays
ooS_pdRatio = pdRatio;
ooS_pl = pl;
ooS_totalPL = totalPL;


end

function [pdRatio, pl, totalPL] = trade_strategy(param1, param2, data)
%% INPUT PARAMETER

% param1 = period ATR
% param2 = multiplier
% data = dataset to trade the strategy

% receive array with supertrend data + trend-direction of data
[supertrend, trend] = mySuperTrend(Instrument, param1, param2, 0); % call SuperTrend calculation and trading, graphics set to 0 -> no drawing

%% DECLARE TRADING FUNCTIONS

function [entry_time_short, entry_price_short, position_size_short] = enterShort(now)
    
    if  (running_trade(now-1) ~= +1) % no running short trade          
            running_trade(now) = -1;
            entry_time_short = now; % save time index of entry signal
            entry_price_short = open(now); % save entry price
            position_size_short = flaEquity *0.01 % risk 1% of initial account size
            count_short_trades = count_short_trades + 1; %how many short trades   
    end
end


function [entry_time_long, entry_price_long, position_size_long] = enterLong(now)
    
    if  (running_trade(now-1) ~= -1) % no running long trade          
            running_trade(now) = 1;
            entry_time_long = now; % save time index of entry signal
            entry_price_long = open(now); % save entry price
            position_size_long = flaEquity *0.01 % risk 1% of initial account size
            count_long_trades = count_long_trades + 1; %how many short trades   
    end
end


function [profit_loss, trade_duration_short] = exitShort(now)


    
    

end


function [profit_loss, trade_duration_long] = exitLong(now)


    
    

end

        
%% SUPERTREND TRADING

for kk = param1+1 : length(data) % cicle through all candles of current data
    
    % careful not to use data which we do not know today! 
    % crossing of price/supertrend calculated on the close prices can only be known and traded tomorrow! -> entry in (kk+1)
    % check: no running trade and price crosses supertrend
        
    % SHORT CROSSING OCCURS
    if close(kk-2) > supertrend(kk-2) && close(kk-1) < supertrend(kk-1)
    
        % no running trade
        if (running_trade(kk-1) == 0) 
            enterShort(kk);
            
        % current long trade           
        elseif running_trade(kk-1) == 1 
            enterShort(kk);
            closeLong(kk);
        end
    end
    
    % LONG CROSSING OCCURS
    if close(kk-2) < supertrend(kk-2) && close(kk-1) > supertrend(kk-1)
            
        % no running trade
        if (running_trade(kk-1) == 0) 
            enterLong(kk);
            
        % current long trade           
        elseif running_trade(kk-1) == 1 
            enterLong(kk);
            closeShort(kk);
        end
    end
end


% Variante statt global variables: nested functions -> https://de.mathworks.com/help/matlab/matlab_prog/nested-functions.html
% m�sste nur das end der FLA function ganz ans ende setzen, dann sollten
% die functions auch ohne global variables auf alles zugreifen k�nnen