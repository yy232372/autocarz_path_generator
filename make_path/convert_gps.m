% convert_gps.m
% 파이썬 환경 문제로 실행되지 않는 convert.py를 완벽하게 대체하는 MATLAB 버전 스크립트입니다.

disp('========== GPS 좌표 변환(latlong2xy) 시작 ==========');

convert_and_save('jeju_in_RDDF.csv', 'jeju_in_RDDF.txt');
convert_and_save('jeju_out_RDDF.csv', 'jeju_out_RDDF.txt');

disp('====================================================');
disp('모든 파일 변환이 완료되었습니다! 🎉');

function convert_and_save(csvFileName, txtFileName)
    if ~isfile(csvFileName)
        warning('파일을 찾을 수 없습니다: %s (해당 폴더에 파일이 있는지 확인하세요)', csvFileName);
        return;
    end
    
    disp(['처리 중: ', csvFileName, ' -> ', txtFileName]);
    
    % readtable을 사용하면 헤더를 자동으로 인식하여 열 순서가 바뀌어도 안전하게 불러옵니다.
    opts = detectImportOptions(csvFileName);
    data = readtable(csvFileName, opts);
    
    fID = fopen(txtFileName, 'w');
    
    for i = 1:height(data)
        % 구조체(테이블)에서 위경도 찾기
        if ismember('Latitude', data.Properties.VariableNames)
            lat = data.Latitude(i);
            lon = data.Longitude(i);
        else
            % 만약 헤더가 없다면 파이썬 원본 스크립트와 동일한 순서 보장 (1: long, 2: lat)
            lon = data{i, 1};
            lat = data{i, 2};
        end
        
        [x, y] = latlong2xy(lat, lon);
        fprintf(fID, '%.8f\t%.8f\n', x, y);
    end
    
    fclose(fID);
end

function [rs_x, rs_y] = latlong2xy(lat, lon)
    RE = 6371.00877;
    GRID = 0.0000005;
    SLAT1 = 30.0;
    SLAT2 = 60.0;
    OLON = 126.0;
    OLAT = 38.0;
    XO = 43;
    YO = 136;

    DEGRAD = pi / 180.0;
    re = RE / GRID;
    slat1 = SLAT1 * DEGRAD;
    slat2 = SLAT2 * DEGRAD;
    olon = OLON * DEGRAD;
    olat = OLAT * DEGRAD;

    sn = tan(pi * 0.25 + slat2 * 0.5) / tan(pi * 0.25 + slat1 * 0.5);
    sn = log(cos(slat1) / cos(slat2)) / log(sn);
    sf = tan(pi * 0.25 + slat1 * 0.5);
    sf = (sf^sn) * cos(slat1) / sn;
    ro = tan(pi * 0.25 + olat * 0.5);
    ro = re * sf / (ro^sn);

    ra = tan(pi * 0.25 + lat * DEGRAD * 0.5);
    ra = re * sf / (ra^sn);

    theta = lon * DEGRAD - olon;
    if theta > pi
        theta = theta - 2.0 * pi;
    end
    if theta < -pi
        theta = theta + 2.0 * pi;
    end
    theta = theta * sn;
    
    rs_x = floor(ra * sin(theta) + XO + 0.5);
    rs_y = floor(ro - ra * cos(theta) + YO + 0.5);
    
    first_xx = 0;%952625;
    first_yy = 0;%8128165;
    	

    
    rs_x = rs_x/2000 + first_xx;
    rs_y = rs_y/2000 + first_yy;
end
