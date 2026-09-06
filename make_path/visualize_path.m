function dataStruct = visualize_path(NumOfPath)
    %Optional
    % clear all; 
    % close all;
    clc;
    % NumOfPath를 입력하지 않으면 1로 설정
    if nargin < 1
        NumOfPath = 1;
    end

    dataStruct = struct();

    for i = 1:NumOfPath
         
        folderPath = 'C:\Users\coros\OneDrive\바탕 화면\자율주행\Path_Maker\path\26_jeju';
        filename = input(['파일 제목을 입력하세요 (data' num2str(i) '.txt): '], 's');
        fullFileName = fullfile(folderPath,filename);
        fieldname = ['path' num2str(i)];
        fig_arg_input = input(['새 창을 띄울 것이면 1을 입력하세요.\n 현재 창 위에 플롯하려면 엔터를 입력하세요 \n'], 's');
        fig_arg = str2double(fig_arg_input);
        if fig_arg == 1
            figure;
        end
        % 파일 읽기
        if isfile(fullFileName)
            % 테이블로 파일을 읽어오기
            data= table2array(readtable(fullFileName));
            dataStruct.(fieldname) = data;
            
            hold on;
            global x;
            global y;
            x = data(:,1);
            
            y = data(:,2);
            
            [~,numCols] = size(data);
            if numCols >2
                index = data(:,3);
                scatter(x, y, 5, index, 'filled');
            
            else    
         
                scatter(x, y, 5, 'filled');
            end
            
            % 생성된 점 옆에 인덱스 표시 (1번부터 길이까지)
            % idxStrs = cellstr(num2str((1:length(x))'));
            % text(x, y, idxStrs, 'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'right', 'FontSize', 8, 'Color', [0.3 0.3 0.3]);
            
            colormap([1 0 0; 0 0 1; 0 1 0; 0 0 0]); 
            axis equal;
    
        else
            error('지정된 파일이 존재하지 않습니다: %s', filename);
        end


   % dcm = datacursormode;  % 현재 figure의 데이터 커서 모드를 활성화
end

