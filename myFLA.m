function [flaEquity] = myFLA(Instrument, totalWindowSize, windowLenght_iS, windowLength_ooS, moveInterval, graphics)
%% INPUT PARAMETER
% Instrument        = which data to load, e.g. 'EURUSD'
% totalWindowSize   = measured from the first data point, how much data
%                   should be taken into calculation for the consecutive walks.
%                   FLA stops when end of totalWindowSize is reached
% windowLenght_iS   = window length of data for in-sample optimization, measured in trading days, default = 518 
% windowLength_ooS  = window length of data for out-of-sample backtest measured in trading days, default = 259 
% moveInterval      = number of trading days to shift (per walk), default = 259
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
%     open;
%     high;
%     low;
%     close;
%     dates;
    
    flaPL(1) = 0; % array with all generated PL
    flaEquity(1) = 100000; % Initial account balance
    
    % global currStartDate;
    % global currEndDate;
    % global priceData;
    
    %----------------------------------------------------------------------
    
    %% DATA PREPARATION
    
    % read data
    [data txt] = xlsread(Instrument);
    
    % assign data - global to be available in all functions
%     open = data(:,1);
%     high = data(:,2);
%     low = data(:,3);
%     close = data(:,4);
     dates = datetime(txt(2:end,1));
    %----------------------------------------------------------------------
    
    %% WALK FORWARD
    
    startDate = dates(1) % first available date in dataset
    endDate = dates(1+totalWindowSize) % endDate = end of totalWindowSize
    startDateIndex = 1;
    endDateIndex = 1+totalWindowSize;
    
    %==================== MAJOR CALCULATION ===============================
    for date = startDateIndex : moveInterval : endDateIndex
        
        data_iS = data(startDateIndex : startDateIndex + windowLenght_iS, :)
        data_ooS = data(startDateIndex + windowLenght_iS + 1 : startDateIndex + windowLenght_iS + 1 + windowLength_ooS, :);
        
        % run in-sample optimization
        % runOptimizer_iS(1,2,3,4);
        runOptimizer_iS(5, 15, 1, 5, 1, 1, data_iS);
        
        % run out-of-sample backtest
        runBacktest_ooS(1, 2, data_ooS);       
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

function [optParam1, optParam2] = runOptimizer_iS(lowerLimit1, upperLimit1, lowerLimit2, upperLimit2, stepParam1, stepParam2, data)
%% INPUT PARAMETER

% lowerLimit1 = lower limit for optimization of parameter 1
% upperLimit1 = upper limit for optimization of parameter 1
% lowerLimit2 = lower limit for optimization of parameter 2
% upperLimit2 = upper limit for optimization of parameter 2
% stepParam1 = step forward for parameter 1 optimization
% stepParam2 = step forward for parameter 2 optimization
% param1 = input parameter 1 for the trading strategy
% param2 = input parameter 2 for the trading strategy

open = data(:,1);
high = data(:,2);
low = data(:,3);
close = data(:,4);
    
% Set current date borders
% currStartDate = date; % date = input from the for-loop
% currEndDate = date + windowLenght_iS; % window-length = input from the FLA-function call

% Initialize arrays with dimensions according to input limits
iS_pdRatio = cell(upperLimit1 - lowerLimit1+1, upperLimit2- lowerLimit2+1);
iS_pl = cell(upperLimit1 - lowerLimit1+1, upperLimit2- lowerLimit2+1);
iS_totalPL = cell(upperLimit1 - lowerLimit1+1, upperLimit2- lowerLimit2+1);

% currData = close(currStartDate : currEndDate, 1); %set current data set with date-borders

% cicle through all parameter combinations and create a heatmap
for ii = lowerLimit1 : stepParam1 : upperLimit1 %cicle through each column
    for jj = lowerLimit2 : stepParam2 : upperLimit2 %cicle through each row
        
        trade_strategy(supertrend, ii, jj, data); %trade on current data set, pd_ratio, pl, totalPL are returned and saved for each walk
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


function [ooS_equity] = runBacktest_ooS(optParam1, optParam2, data)
%% INPUT PARAMETER

% optParam1 = in-sample optimized input parameter 1
% optParam2 = in-sample optimized input parameter 2

open = data(:,1);
high = data(:,2);
low = data(:,3);
close = data(:,4);

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
[supertrend, trend] = mySuperTrend(data, param1, param2, 0); % call SuperTrend calculation and trading, graphics set to 0 -> no drawing

open = data(:,1);
high = data(:,2);
low = data(:,3);
close = data(:,4);

%% DECLARE TRADING FUNCTIONS

function [entry_time_short, entry_price_short, position_size_short] = enterShort(now)
    
    if  (running_trade(now-1) ~= +1) % make sure no running short trade          
            running_trade(now) = -1;
            entry_time_short = now; % save time index of entry signal
            entry_price_short = open(now); % save entry price
            position_size_short = flaEquity *0.01; % risk 1% of initial account size
            count_short_trades = count_short_trades + 1; %how many short trades   
    end
    
end


function [entry_time_long, entry_price_long, position_size] = enterLong(now)
    
    if  (running_trade(now-1) ~= -1) % make sure no running long trade          
            running_trade(now) = 1;
            entry_time_long = now; % save time index of entry signal
            entry_price_long = open(now); % save entry price
            position_size = flaEquity *0.01; % risk 1% of initial account size
            count_long_trades = count_long_trades + 1; %how many short trades   
    end
    
end


function [profit_loss, trade_duration_short] = exitShort(now)

    if  (running_trade(now-1) == -1) % make sure there is a running short trade        
            running_trade(now) = 0;
            trade_duration_short(now) = (now) - (entry_time_short - 1); % calc number of bars of trade duration (for further statistics)
            profit_loss(now) = (entry_price_short - open(ii)) * position_size; 
            short_exit = short_exit + 1; % count how many short trades are stopped out
    end
    
end


function [profit_loss, trade_duration_long] = exitLong(now)

    if  (running_trade(now-1) == 1) % make sure there is a running short trade        
            running_trade(now) = 0;
            trade_duration_long(now) = (now) - (entry_time_long - 1); % calc number of bars of trade duration (for further statistics)
            profit_loss(now) = (entry_price_long - open(ii)) * position_size; 
            short_exit = short_exit + 1; % count how many short trades are stopped out
    end
    
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
        elseif (running_trade(kk-1) == 1)
            enterShort(kk);
            closeLong(kk);
        end
            
    
    % LONG CROSSING OCCURS
    elseif close(kk-2) < supertrend(kk-2) && close(kk-1) > supertrend(kk-1)
            
        % no running trade
        if (running_trade(kk-1) == 0)
            enterLong(kk);
            
        % current long trade           
        elseif running_trade(kk-1) == 1 
            enterLong(kk);
            closeShort(kk);
        end
        
    elseif (running_trade(kk-1) == -1) % if we have a running short trade set running trade to 1 for each bar until exit 
        running_trade(kk) = -1;
        
    elseif (running_trade(kk-1) == 1) % if we have a running long trade set running trade to 1 for each bar until exit 
        running_trade(kk) = 1;
    
    end    
end
end

% =========================================================================

% DEFAULT INPUT
% myFLA(Instrument, totalWindowSize, windowLenght_iS, windowLength_ooS, moveInterval, graphics)
% myFLA('EURUSD', 2000, 518, 259, 259, 0)

% Variante statt global variables: nested functions -> https://de.mathworks.com/help/matlab/matlab_prog/nested-functions.html
% m�sste nur das end der FLA function ganz ans ende setzen, dann sollten
% die functions auch ohne global variables auf alles zugreifen k�nnen