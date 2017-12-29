% function [pdRatio, cleanPL, pdMsgCode] = tradeStrategy(param1, param2, data, obj)
function [cleanPL] = tradeStrategy(param1, param2, data, obj)
    % INPUT PARAMETER
    % For SuperTrend-Trading:
    % param1 = period ATR
    % param2 = multiplier

    % CALCULATE SUPERTREND
    % receive array with supertrend data and trend-direction (not necessary) of data
    % the input data for supertrend calculation is incl. datapoints at the beginning (size of obj.windowLength_ooS) which are only for ST calculation, not for trading with them
    % later on. 
    [supertrend, trend] = mySuperTrend(data, param1, param2, 0); % call SuperTrend calculation and trading, graphics set to 0 -> no drawing
    
    % Trim the arrays so the first datapoints are not used for trading -> they are only for ST calculation (see lines ~130-160)
    % Starting only from the second walk, as the first walk has no added datapoints at the beginning
    
    if (obj.count_walks > 1)
        supertrend = supertrend(obj.windowLength_ooS +1 : end);
        trend = trend(obj.windowLength_ooS +1: end);
    end
    
    % if supertrend could not be calculate, e.g. because atrPeriod > available data
    if (or(isnan(supertrend), isnan(trend)))
        pdRatio = NaN;
        cleanPL = NaN;
        pdMsgCode = 4;
        return;
    end

    % PREPARE DATA
    % use only data which is meant for trading, the first datapoints are trimmed, they are only for ST calculation
    if (obj.count_walks == 1)
        open = data(:,1);
        high = data(:,2);
        low = data(:,3);
        close = data(:,4);
        
    elseif (obj.count_walks > 1)
        open = data(obj.windowLength_ooS +1: end ,1);
        high = data(obj.windowLength_ooS +1: end ,2);
        low = data(obj.windowLength_ooS +1: end ,3);
        close = data(obj.windowLength_ooS +1: end ,4);
        %plotSuperTrend(open, high, low, close, supertrend) % for debugging
    end

    % INITIALIZE 
    profitLoss = 0;
    runningTrade(1:param1, :) = 0; % set first values of the array to 0 -> no running trade at the beginning

    entryTimeShort = [];
    entryTimeLong = [];
    entryPriceShort = [];
    entryPriceLong = [];

    exitCounterShort = [];
    exitCounterLong = [];
    tradeCounterShort = [];
    tradeCounterLong = [];
    tradeDurationLong = [];
    tradeDurationShort = [];

    % DECLARE TRADING FUNCTIONS

    function [] = enterShort(now)
        
                runningTrade(now) = -1;
                entryTimeShort = (now); % save time index of entry signal
                entryPriceShort = open(now); % save entry price
                tradeCounterShort = tradeCounterShort + 1; % count how many short trades      
    end

    function [] = enterLong(now)
        
                runningTrade(now) = 1;
                entryTimeLong = now; % save time index of entry signal
                entryPriceLong = open(now); % save entry price
                tradeCounterLong = tradeCounterLong + 1; % count how many short trades   
    end

    function [] = exitShort(now)
        
        if  (runningTrade(now-1) == -1) % make sure there is a running short trade        
            runningTrade(now) = 0;
            tradeDurationShort(now) = (now) - (entryTimeShort - 1); % calculate number of bars of trade duration (for further statistics)
            profitLoss(now,:) = (entryPriceShort - open(now,:)) * obj.investment; % calculate P/L in USD
            exitCounterShort = exitCounterShort + 1; % count how many short trades are stopped out
        end
    end

    function [] = exitLong(now)

        if  (runningTrade(now-1) == 1) % make sure there is a running short trade       
            runningTrade(now) = 0;
            tradeDurationLong(now) = (now) - (entryTimeLong - 1); % calculate number of bars of trade duration (for further statistics)
            profitLoss(now,:) = (open(now,:) - entryPriceLong) * obj.investment; % calculate P/L in USD
            exitCounterLong = exitCounterLong + 1; % count how many short trades are stopped out
        end
    end


    % SUPERTREND TRADING

    for kk = param1+1 : length(close) % cicle through all candles of current data

    % ======================
%         Debugging
%             if kk == 753
%                 x = 0;
%             end
    % ======================

        % careful not to use data which we do not know today! 
        % crossing of price/supertrend calculated on the close prices can only be known and traded tomorrow! -> entry in (kk+1)

        % SHORT CROSSING OCCURED ON YESTERDAYS CLOSE 
        % check: supertrend has a real value + supertrend crossing occured yesterday
        if supertrend(kk-2) > 0 && supertrend(kk-1) > 0 &&(close(kk-2) > supertrend(kk-2) && close(kk-1) <= supertrend(kk-1))

            % no running trade
            if (runningTrade(kk-1) == 0) % if currently no running trade
                enterShort(kk);

            % current long trade           
            elseif (runningTrade(kk-1) == 1) % if currently running long trade
                exitLong(kk);
                enterShort(kk);            
            end


        % LONG CROSSING OCCURED ON YESTERDAYS CLOSE
        elseif supertrend(kk-2) > 0 && supertrend(kk-1) > 0 && (close(kk-2) < supertrend(kk-2) && close(kk-1) >= supertrend(kk-1))

            % no running trade
            if (runningTrade(kk-1) == 0) % if currently no running trade
                enterLong(kk);

            % current long trade           
            elseif (runningTrade(kk-1) == -1) % if currently running short trade
                exitShort(kk);
                enterLong(kk);
            end


        % NO CROSSING OCCURED - NO CHANGES IN A RUNNING TRADE    
        else 

            if (runningTrade(kk-1) == -1) % if yesterday = running short trade -> today = running short trade
                runningTrade(kk) = -1;


            elseif (runningTrade(kk-1) == 1) % if yesterday = running long trade -> today = running long trade
                runningTrade(kk) = 1;


            elseif (runningTrade(kk-1) == 0) % if yesterday = no trade -> today = no trade
                runningTrade(kk) = 0;

            end    
        end   

        % if last datapoint reached -> close all running trades    
        if kk == length(close)

            if runningTrade(kk-1) == -1
                exitShort(kk);

            elseif runningTrade(kk-1) == 1
                exitLong(kk);

            end
        end
    end

    % KEY FIGURES 
    
    totalPL = sum(profitLoss); 
    totalPL_percent = (totalPL / obj.investment) * 100;

    % Clean profitLoss array from zeros
    cleanPL = profitLoss; % use new array for further changes -> profitLoss array should not be changed
    cleanPL(find(cleanPL == 0)) = []; % delete value if value = 0

    % Calculate cleanEquity curve with clean profitLoss array
    cleanEquity(1) = obj.investment; % first vaule = initial account balance

    % Check how many datapoints available
    if length(cleanPL) == 0 % no trade was computed

        maxDrawdown = NaN;
        pdRatio = 0;
        pdMsgCode = 1; % error code for detecting why no pd-ratio could be calculated

    elseif length(cleanPL) == 1 % only one trade was computed

        cleanEquity(2) = cleanEquity(1) + cleanPL(1);
        
        if(cleanEquity(2) > cleanEquity(1)) % only one positive trade
            maxDrawdown = 0.01; % set manually so calculation is possible -> value is a percentage value -> 0.01%
            pdRatio = totalPL_percent / maxDrawdown;
            pdMsgCode = 3;
            
        else % only one negative trade
            pdRatio = 0;
            pdMsgCode = 2; % error code for detecting why no pd-ratio could be calculated
        end

    else % more than 1 trades were computed
        
        % Preallocate cleanEquity -> speed
        cleanEquity(2:length(cleanPL)+1,1) = NaN;
        
        for kk = 1:length(cleanPL)
 
            % calculate equity curve by adding up each profit/loss to current account balance
            cleanEquity(kk+1,1) = cleanEquity(kk) + cleanPL(kk); %[�]        
            cleanEquity(cleanEquity <= 0) = 0.01; % if equity would go below zero, set balance to 1cent (negative balance not possible)
        end

        % Calculate maximum drawdown of the equity-curve - use internal matlab function maxdrawdown(), output = % value      
        maxDrawdown = maxdrawdown(cleanEquity) * 100;
        
        % Calculate ProfitDrawdownRatio
        if maxDrawdown ~= 0

            pdRatio = totalPL_percent / maxDrawdown;
            pdMsgCode = 0; 
            
        else
            maxDrawdown = 0.01; % set manually so calculation is possible -> value is a percentage value -> 0.01%
            pdRatio = totalPL_percent / maxDrawdown;
            pdMsgCode = 3; % error code for detecting why no pd-ratio could be calculated
            
        end
    end 
    
    % Plot supertrends where no trade was computed or supertrend could not be computed
%     if (obj.count_walks > 1 && obj.graphics == 1 && (pdMsgCode == 1 || pdMsgCode == 5))
%         plotSuperTrend(open, high, low, close, supertrend)
%     end
end