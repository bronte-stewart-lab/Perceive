function percept_load(subjectID,files)
% goals: 1) import Json datafile, 2)save Perceive time domain outputs to CSV files
% inputs: 1)json filename, 2)subject code
% outputs: 1)mat file for json data, 2)csv for time domain
% dependency: perceive 
% written by JWC
        

%% below is CC addition

if ischar(files)
    files = {files};
end

for a = 1:length(files)
    filename = files{a};
    
        
        [~, base_filename] = fileparts(filename);
        session =  base_filename(end-14:end);
        [alldata, hdr] = perceive(filename,subjectID);
        
        %disp(['channels',js.MostRecentInSessionSignalCheck(:).Channel])
        %disp(['frequency',js.MostRecentInSessionSignalCheck(:).PeakFrequencies])
        
        disp('loading json complete')
        js=hdr.js;
        
                            
        %% below is Jin Woo code 
        trial=1;
        file_label=1;
        while trial <= length(js.BrainSenseTimeDomain)
            trialname=['_output' num2str(file_label) '.csv'];
            all_trial=1;
            flag=0;
            count=1;
            while all_trial <= size(alldata,2)
                if ~isfield(alldata{1,all_trial},'datatype')
                    all_trial=all_trial+1;
                    continue
                end
                for i=1:size(alldata{1,all_trial}.trial{1,1},1)
                    if(trial==count)
                        js.BrainSenseTimeDomain(trial).TimeDomainData=alldata{1,all_trial}.trial{1,1}(i,:)';
                        flag=1;
                    end
                    count=count+1;
                end
                if(flag==1)
                    break
                end
                all_trial=all_trial+1;
            end
            start_time=js.BrainSenseTimeDomain.FirstPacketDateTime;
            time_length=size(js.BrainSenseTimeDomain(trial).TimeDomainData,1);
            col_names={'localTime', 'DerivedTime','TD_key0','TD_key2','TD_key1','TD_key3','TD_samplerate','Adaptive_CurrentProgramAmplitudesInMilliamps_1','Adaptive_CurrentProgramAmplitudesInMilliamps_2','Adaptive_CurrentProgramAmplitudesInMilliamps_3','Adaptive_CurrentProgramAmplitudesInMilliamps_4','Adaptive_StimRateInHz','Adaptive_Ld0_highThreshold','Adaptive_Ld0_lowThreshold','Adaptive_Ld1_highThreshold','Adaptive_Ld1_lowThreshold'};
            cell_array=cell(time_length, length(col_names));
            cell_array(:)={"NaN"};
        
            %fills local / derived time (assuming that firstpacketdatetime refers to the last data of the first packet)
            %similar to the first packet date time
            dateString=js.BrainSenseTimeDomain(trial).FirstPacketDateTime;
            dateTimeObj = datetime(dateString, 'InputFormat', 'uuuu-MM-dd''T''HH:mm:ss.SSS''Z''', 'TimeZone', 'UTC');
            unixTime = posixtime(dateTimeObj)*1000;
            save_unixTime=unixTime;
            packet_sizes=strsplit(js.BrainSenseTimeDomain(trial).GlobalPacketSizes,',');
            for i=str2num(packet_sizes{1}):size(js.BrainSenseTimeDomain(trial).TimeDomainData,1)
                cell_array(i,2)=num2cell(int64(unixTime));
                dateTimeObj = datetime(unixTime/1000, 'ConvertFrom', 'posixtime', 'TimeZone', 'UTC');
                formattedDate = datestr(dateTimeObj, 'dd-mmm-yyyy HH:MM:SS.FFF');
                cell_array(i,1)=cellstr(formattedDate);
                unixTime=unixTime+(1000/js.BrainSenseTimeDomain(trial).SampleRateInHz);
            end
            unixTime=save_unixTime;
            for i=str2num(packet_sizes{1}):-1:1
                cell_array(i,2)=num2cell(int64(unixTime));
                dateTimeObj = datetime(unixTime/1000, 'ConvertFrom', 'posixtime', 'TimeZone', 'UTC');
                formattedDate = datestr(dateTimeObj, 'dd-mmm-yyyy HH:MM:SS.FFF');
                cell_array(i,1)=cellstr(formattedDate);
                unixTime=unixTime-(1000/js.BrainSenseTimeDomain(trial).SampleRateInHz);
            end
        
            %fills TD_key (starting from 0)
            idx=find(strcmp(col_names,'TD_key0'));
            cell_array(:,idx)=num2cell(js.BrainSenseTimeDomain(trial).TimeDomainData);
            skip=0;
            for i=1:length(js.BrainSenseTimeDomain)-trial
                if js.BrainSenseTimeDomain(trial).FirstPacketDateTime == js.BrainSenseTimeDomain(trial+i).FirstPacketDateTime
                    cell_array(:,idx+i)=num2cell(js.BrainSenseTimeDomain(trial+i).TimeDomainData);
                    skip=i;
                else
                    break;
                end
            end
        
            %fills TD_samplerate (considering GlobalPacketSizes)
            idx_print=0;
            idx_read=1;
            idx_col=find(strcmp(col_names,'TD_samplerate'));
            packet_sizes=strsplit(js.BrainSenseTimeDomain(trial).GlobalPacketSizes,',');
            while idx_print <= size(js.BrainSenseTimeDomain(trial).TimeDomainData,1)
                idx_print=idx_print+str2num(packet_sizes{idx_read});
                cell_array(idx_print,idx_col)=num2cell(js.BrainSenseTimeDomain(trial).SampleRateInHz);
                idx_read=idx_read+1;
            end
        
            %fills Adaptive_CurrentProgramAmplitudesInMilliamps_1 through 4, based
            %on the ticks (currently, right is _1 and left is _2. Yet proceeded for
            %multiple stimuli
            %fills Adaptive_StimRateInHz, Adaptive_high and lowThresholds (fills all rows for now)
            TD_packet_sizes=strsplit(js.BrainSenseTimeDomain(trial).GlobalPacketSizes,',');
            TD_ticks=strsplit(js.BrainSenseTimeDomain(trial).TicksInMses,',');
            for i=1:length(js.BrainSenseLfp)
                if(js.BrainSenseLfp(i).FirstPacketDateTime==js.BrainSenseTimeDomain(trial).FirstPacketDateTime)
                    idx_lfpticks=1;
                    loc=0;
                    for j=1:length(TD_packet_sizes)-1
                        if(isempty(TD_packet_sizes{j+1}))
                            break;
                        end
                        loc=loc+str2num(TD_packet_sizes{j});
                        lfp_ticks=js.BrainSenseLfp(i).LfpData(idx_lfpticks).TicksInMs;
                        if(str2num(TD_ticks{j}) <= lfp_ticks && lfp_ticks < str2num(TD_ticks{j+1}))
                            temp_loc=loc+int64(str2num(TD_packet_sizes{j+1})*((lfp_ticks-str2num(TD_ticks{j}))/(str2num(TD_ticks{j+1})-str2num(TD_ticks{j}))));
                            idx_col=find(strcmp(col_names,'Adaptive_CurrentProgramAmplitudesInMilliamps_1'));
                            cell_array(temp_loc,idx_col)=num2cell(js.BrainSenseLfp(i).LfpData(idx_lfpticks).Right.mA);
                            idx_col=find(strcmp(col_names,'Adaptive_CurrentProgramAmplitudesInMilliamps_2'));
                            cell_array(temp_loc,idx_col)=num2cell(js.BrainSenseLfp(i).LfpData(idx_lfpticks).Left.mA);
        
                            if isfield(js.BrainSenseLfp(i).TherapySnapshot, 'Right')
                                idx_col=find(strcmp(col_names,'Adaptive_Ld0_highThreshold'));
                                cell_array(temp_loc,idx_col)=num2cell(js.BrainSenseLfp(i).TherapySnapshot.Right.UpperLimitInMilliAmps);
                                idx_col=find(strcmp(col_names,'Adaptive_Ld0_lowThreshold'));
                                cell_array(temp_loc,idx_col)=num2cell(js.BrainSenseLfp(i).TherapySnapshot.Right.LowerLimitInMilliAmps);
                                idx_col=find(strcmp(col_names,'Adaptive_StimRateInHz'));
                                cell_array(temp_loc,idx_col)=num2cell(js.BrainSenseLfp(i).TherapySnapshot.Right.RateInHertz);
                            end
                            if isfield(js.BrainSenseLfp(i).TherapySnapshot, 'Left')
                                idx_col=find(strcmp(col_names,'Adaptive_Ld1_highThreshold'));
                                cell_array(temp_loc,idx_col)=num2cell(js.BrainSenseLfp(i).TherapySnapshot.Left.UpperLimitInMilliAmps);
                                idx_col=find(strcmp(col_names,'Adaptive_Ld1_lowThreshold'));
                                cell_array(temp_loc,idx_col)=num2cell(js.BrainSenseLfp(i).TherapySnapshot.Left.LowerLimitInMilliAmps);
                                idx_col=find(strcmp(col_names,'Adaptive_StimRateInHz'));
                                cell_array(temp_loc,idx_col)=num2cell(js.BrainSenseLfp(i).TherapySnapshot.Left.RateInHertz);
                            end
        
                            idx_lfpticks=idx_lfpticks+1;
                            if(idx_lfpticks>size(js.BrainSenseLfp(i).LfpData,1))
                                break;
                            end
                            j=j-1;
                        end
                    end
                end
            end
                    
            %save csv file
            output=cell2table(cell_array);
            output=renamevars(output,output.Properties.VariableNames,col_names);
            writetable(output,fullfile(subjectID,[subjectID '_ses-' session trialname]));
            disp(['saved ' subjectID '_ses-' session trialname])
        
        
            trial=trial+skip+1;
            file_label=file_label+1;
        end
        disp('saving csv complete')
        
        
       
        % localTime - js.BrainSenseTimeDomain.FirstPacketDateTime (need to find pair based on this)
        % DerivedTime - converted localtime in unix
        % *TD_key - js.BrainSenseTimeDomain.TimeDomainData 
        % TD_samplerate - hdr.jr.BrainSenseTimeDomain.SampleRateInHz
        % Accel_XSamples - NaN
        % Accel_YSamples - NaN
        % Accel_ZSamples - NaN
        % Accel_samplerate - NaN
        % Adaptive_CurrentAdaptiveState hdr.jr.BrainSenseLfp.therapySnapshot.Right(Left).AdaptiveTherapyStatus (?)
        % *Adaptive_CurrentProgramAmplitudesInMilliamps - js.BrainSenseLfp.LfpData (right or left)
        % Adaptive_IsInHoldOffOnStartup
        % Adaptive_Ld0DetectionStatus
        % Adaptive_Ld1DetectionStatus
        % Adaptive_PreviousAdaptiveState
        % Adaptive_SensingStatus
        % Adaptive_StateEntryCount
        % Adaptive_StateTime
        % Adaptive_StimFlags
        % Adaptive_StimRateInHz - js.BrainSenseLfp.TherapySnapshot.Right(Left).RateInHertz 
        % Adaptive_Ld0_featureInputs_1
        % Adaptive_Ld0_featureInputs_2
        % Adaptive_Ld0_featureInputs_3
        % Adaptive_Ld0_featureInputs_4
        % Adaptive_Ld0_fixedDecimalPoint
        % Adaptive_Ld0_highThreshold - js.BrainSenseLfp.TherapySnapshot.Right(Left).UpperLfpThreshold
        % Adaptive_Ld0_lowThreshold - js.BrainSenseLfp.TherapySnapshot.Right(Left).LowerLfpThreshold
        % Adaptive_Ld0_output
        % Adaptive_Ld1_featureInputs_1
        % Adaptive_Ld1_featureInputs_2
        % Adaptive_Ld1_featureInputs_3
        % Adaptive_Ld1_featureInputs_4
        % Adaptive_Ld1_fixedDecimalPoint
        % Adaptive_Ld1_highThreshold - js.BrainSenseLfp.TherapySnapshot.Right(Left).UpperLfpThreshold
        % Adaptive_Ld1_lowThreshold - js.BrainSenseLfp.TherapySnapshot.Right(Left).LowerLfpThreshold
        % Adaptive_Ld1_output

         %% below CC addition 
        % Save json info
        filePath = fullfile(subjectID, ['ses-' session], 'js.mat');
        save(filePath, 'js');
        disp('saving js complete')
        
end
end