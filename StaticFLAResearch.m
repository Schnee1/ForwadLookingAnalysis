% INPUT
Instrument = 'EURUSD';

% SETUP LOG FILE
filePath = horzcat(Instrument, '.txt');
columnNames = 'windowLength_iS / windowLength_ooS / ForwardEfficiency';

fileID = fopen(filePath, 'wt'); % open log file for writing
fprintf(fileID, '\t\t\t%s\n\n', Instrument); % write Instrument name to the log file
fprintf(fileID, '%s\n\n', columnNames); % write column headers to the log file
formatSpec = '\t%2d\t\t %2d\t\t %.4g\n'; % predefine the format of the printed variables

% =============================  RUN STATIC ANALYSIS  =====================================
% =========================================================================================

tic
for i = 200 : 100 : 200 % in sample length
    for j = 100 : 50 : 200 % out of sample length
    
    % myFLA('Instrument', totalDataSize, windowLenght_iS, windowLength_ooS, graphics)
    analysis = myFLA(Instrument, 2000, i, j, 0); 

    % RUN ANALYSIS
    % ForwardEfficiency is returned by RunFLA() and assigned to the analysis object.
    analysis.ForwardEfficiency = RunFLA(analysis);
    
    % WRITE TABLE
     T = [analysis.windowLenght_iS, analysis.windowLength_ooS, analysis.ForwardEfficiency];

    fprintf(fileID, formatSpec, T);
    
    end
end
timer = toc;

% =========================================================================================

fprintf(fileID, '\nElapsed time: %.4g seconds', timer); % print timer

beep; % audio information that analysis is finished
fclose(fileID); %close the log file