classdef myFLA
    
    properties 
        count_walks = 0;
        investment = 10.000;  
        Instrument;             % which data to load, e.g. 'EURUSD'
        totalDataSize;          % measured from the first data point, how much data should be taken into calculation for the consecutive walks. FLA stops when end of totalWindowSize is reached
        windowLenght_iS;        % window length of data for in-sample optimization, measured in trading days, default = 518
        windowLength_ooS;       % window length of data for out-of-sample backtest measured in trading days, default = 259 
        graphics;               % if graphics == 1 plotting is activated
    end
    
    methods
        
        function obj = myFLA(Instrument, totalDataSize, windowLenght_iS, windowLength_ooS, graphics)
            obj.Instrument = Instrument;
            obj.totalDataSize = totalDataSize;
            obj.windowLenght_iS = windowLenght_iS;%
            obj.windowLength_ooS = windowLength_ooS;%
            obj.graphics = graphics;
        end % Constructor
        function [] = RunFLA(obj)   

            % DATA PREPARATION
            % read price data and dates
            [data txt] = xlsread(obj.Instrument);

            % save dates in array
            dates = txt(2:end,1);
            %----------------------------------------------------------------------

            % CHECK FOR CORRECT INPUT

            if obj.graphics > 1
                errordlg('Please check your input parameters, graphics must not be greater than 1');
                disp('Error, see messagebox!');
                return;
            end

            if obj.graphics < 0
                errordlg('Please check your input parameters, graphics must not be less than 1');
                disp('Error, see messagebox!');
                return;
            end

            if (obj.windowLenght_iS + obj.windowLength_ooS) > obj.totalDataSize
                errordlg('Please check your input parameters, in-sample + out-of-sample window length must not exceed totalDataSize')
                disp('Error, see messagebox!');
                return;
            end

            % INITIALIZE VECTORS/ARRAYS/VARIABLES

            % global to be available in all functions          
            %global investment;

            % ======================= USER INPUT ==============================

            %investment = 10000; % amount of $ to invest per trade = account size -> 100% of acc size are invested in the market all the time

            % Params for ATR optimization - ATR parameters must be integers -> no decimals
            lowLim_ATR = 10;
            upLim_ATR = 50;
            step_ATR = 1; 

                % in case user chose decimals, delete decimals to ensure correct calulations in ATR calculatoin
                lowLim_ATR = round(lowLim_ATR); 
                upLim_ATR = round(upLim_ATR);
                step_ATR = round(step_ATR);

            % Params for multiplier optimization - Multiplier parameters can have decimals
            lowLim_mult = 1;
            upLim_mult = 7;
            step_mult = 0.5;  

            % =================================================================

            iS_pdRatios = 0;
            ooS_pdRatios = 0;
            iS_ProfitLoss = NaN; 
            ooS_ProfitLoss = NaN;
            ooS_Equity = 0; % array with all generated PL

            % WALK FORWARD

            % Assign values for the first walk
            startDateIndex = 1;
            endDateIndex = obj.totalDataSize;

            %==================== MAJOR CALCULATION ===============================

            % data is moved each walk by the size obj.windowLength_ooS
            for date = startDateIndex : obj.windowLength_ooS : endDateIndex

                obj.count_walks = obj.count_walks + 1;

            %         ---------------------
            %         DEBUGGING
            %         if count_walks == 8        
            %             x = 0;            
            %         end
            %         ---------------------

                % ONLY FOR PRINTING TO THE COMMAND WINDOW

                if (date > length(dates)) % if startDate_iS exceeds the array size
                    msgbox('ATTENTION! data_iS exceeds the size of the dataseries, no data for walk forward left -> end');
                    obj.count_walks = obj.count_walks - 1; % Walk is not completely done
                    break; % exit the loop
                else
                    startDate_iS(obj.count_walks,:) = dates(date);  % startDate_iS does not exceed the array size
                end

                if (date + obj.windowLenght_iS > length(dates)) % if endDate_iS exceeds the array size
                    msgbox('ATTENTION! data_iS exceeds the size of the dataseries, no data for walk forward left -> end');
                    obj.count_walks = obj.count_walks - 1; % Walk is not completely done
                    break; % exit the loop
                else
                    endDate_iS(obj.count_walks,:) = dates(date + obj.windowLenght_iS); % endDate_ooS does not exceed the array size
                end

                if (date + obj.windowLenght_iS + 1 > length(dates)) % if startDate_ooS exceeds the array size
                    msgbox('ATTENTION! data_iS exceeds the size of the dataseries, no data for walk forward left -> end');  
                    obj.count_walks = obj.count_walks -1;
                    break; % exit the loop
                else
                    startDate_ooS(obj.count_walks,:) = dates(date + obj.windowLenght_iS + 1); % endDate_ooS does not exceed the array size
                end

                if (date + obj.windowLenght_iS + 1 + obj.windowLength_ooS > length(dates)) % if endDate_ooS exceeds the array size
                    endDate_ooS(obj.count_walks,:) = dates(length(dates));
                    msgbox('ATTENTION! endDate_ooS exceeds the dimension of the dataseries and was trimmed to fit to the array-size');        
                else
                    endDate_ooS(obj.count_walks,:) = dates(date + obj.windowLenght_iS + 1 + obj.windowLength_ooS); % endDate_ooS does not exceed the array size
                end

                % Define the dataset for the first walk == normal calculation
                if (obj.count_walks == 1)

                    data_iS = data(date : date + obj.windowLenght_iS - 1, :); % no data check needed, already done above

                    if (date + obj.windowLenght_iS + obj.windowLength_ooS > length(dates)) % if endDate_ooS exceeds the array size
                        data_ooS = data(date + obj.windowLenght_iS : length(dates)-1, :);
                        disp('data_ooS was trimmed to fit the array size');        
                    else
                        data_ooS = data(date + obj.windowLenght_iS : date + obj.windowLenght_iS + obj.windowLength_ooS - 1, :); % endDate_ooS does not exceed the array size
                    end

                end

                % Define the dataset for 2nd and all following walks -> add 1 time ooS data size to the beginning of the dataset for Supertrend calculation
                % -> with this logic Supertrend has values from the first real starting point       
                if (obj.count_walks > 1)

                    % add windowLenth_ooS size to the beginning of the data
                    if (date - obj.windowLength_ooS) > 0 % if start_date would exceed first datapoint of array
                        data_iS = data(date - obj.windowLength_ooS : date + obj.windowLenght_iS - 1, :);
                    else
                        data_iS = data(1 : date + obj.windowLenght_iS - 1, :); % start from the first available datapoint also in the second walk
                    end

                    % add windowLenth_ooS size to the beginning of the data
                    if (date + obj.windowLenght_iS + obj.windowLength_ooS > length(dates)) % if endDate_ooS exceeds the array size
                        data_ooS = data(date - obj.windowLength_ooS + obj.windowLenght_iS : length(dates)-1, :);
                        disp('data_ooS was trimmed to fit the array size');        
                    else
                        data_ooS = data(date - obj.windowLength_ooS + obj.windowLenght_iS : date + obj.windowLenght_iS + obj.windowLength_ooS - 1, :); % endDate_ooS does not exceed the array size
                    end

                end

            % ========================= WALK FORWARD ==============================

                % run in-sample optimization
                [optParam1, optParam2] = runOptimizer(lowLim_ATR, upLim_ATR, step_ATR, lowLim_mult, upLim_mult, step_mult, data_iS, obj);
                [iS_pdRatio, iS_cleanPL, iS_pdMsgCode] = runBacktest(optParam1, optParam2, data_iS, obj); % for later comparison to ooS-pdRatio

                % run out-of-sample backtest        
                [ooS_pdRatio, ooS_cleanPL, ooS_pdMsgCode] = runBacktest(optParam1, optParam2, data_ooS, obj);    
                % mySuperTrend(data_ooS, optParam1, optParam2, 1); % for testing purpose - to see on which chart is traded

            % =====================================================================

                % Save the results in vectors for later display in command window                     
                optParams(obj.count_walks,:) = [optParam1, optParam2];
                ooS_pdRatios(obj.count_walks,1) = ooS_pdRatio;  
                ooS_pdRatios(obj.count_walks,2) = ooS_pdMsgCode; % info about pd-ratio calculation
                iS_pdRatios(obj.count_walks,1) = iS_pdRatio;
                iS_pdRatios(obj.count_walks,2) = iS_pdMsgCode; % info about pd-ratio calculation

                % Calculate the combined forwardLooking-P&L by combining each out-of-sample P&L vector   
                ooS_ProfitLoss = vertcat(ooS_ProfitLoss, ooS_cleanPL);
                iS_ProfitLoss = vertcat(iS_ProfitLoss, iS_cleanPL);
            end

            % calculate final equity curve by adding up each profit/loss to current account balance
            ooS_Equity(1) = obj.investment; % first data point = initial account balance = investment size
            ooS_Equity(2:length(ooS_ProfitLoss),1) = NaN; % Preallocate for speed

            iS_Equity(1) = obj.investment; % first data point = initial account balance = investment size
            iS_Equity(2:length(iS_ProfitLoss),1) = NaN; % Preallocate for speed

            for kk = 2:length(ooS_ProfitLoss)

                ooS_Equity(kk,1) = ooS_Equity(kk-1) + ooS_ProfitLoss(kk); %[�]               

            end

            for kk = 2:length(iS_ProfitLoss)

                iS_Equity(kk,1) = iS_Equity(kk-1) + iS_ProfitLoss(kk); %[�]

            end

            % Create char-array for error-code definitions, plot to console in next section
            pdMsg = {'pd_ratio error messages';'0 = calculation ok';'1 = no trade computed';'2 = only one negative trade computed';'3 = only one positive trade computed';'4 = no negative trades - maxdrawdown = 0';'5 = SuperTrend could not be calculated'};

            % Print to command window for controlling dates
            obj.count_walks;
            startDate_iS;
            endDate_iS;
            startDate_ooS;
            endDate_ooS;
            optParams   
            iS_pdRatios
            ooS_pdRatios
            disp(pdMsg)

            % Plot the combined FLA-Equity curve
            if (obj.graphics == 1)

                figure;
                    % IN SAMPLE PLOTTING
                    s1 = subplot(1,2,1);
                        hold on                
                            plot(iS_Equity, 'k'); 
                            title(s1, 'IN SAMPLE');  
                            ylabel(s1, 'Account Balance [�]');
                            xlabel(s1, '# of Trades');
                        hold off

                    % OUT OF SAMPLE PLOTTING
                    s2 = subplot(1,2,2); 
                        hold on                
                            plot(ooS_Equity, 'r'); % ooS_Equity = each ooS_equity combined
                            title(s2, 'OUT OF SAMPLE');
                            ylabel(s2, 'Account Balance [�]');
                            xlabel(s2, '# of Trades');
                        hold off  
            end
        end
        
    end  
end








