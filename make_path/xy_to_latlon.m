% xy_to_latlon.m
% X, Y 좌표를 원래의 위도(Latitude), 경도(Longitude)로 변환하는 스크립트입니다.

disp('========== XY 좌표 -> GPS 위경도 변환 ==========');

% 기본 타겟 파일
defaultFile = 'c:\Users\coros\OneDrive\바탕 화면\자율주행\Path_Maker\Path\26_jeju\곡선완화\대회측이춘패스 수정본\in_edit.txt';

if isfile(defaultFile)
    inFile = defaultFile;
else
    [file, path] = uigetfile('*.txt;*.csv', '변환할 XY 데이터 파일을 선택하세요');
    if isequal(file, 0)
        disp('취소되었습니다.');
        return;
    end
    inFile = fullfile(path, file);
end

[filepath, name, ext] = fileparts(inFile);
outFile = fullfile(filepath, [name, '_latlon', ext]);

disp(['입력 파일: ', inFile]);
disp(['출력 파일: ', outFile]);

% 데이터 불러오기
try
    data = readmatrix(inFile);
catch
    warning('파일을 텍스트/숫자 행렬로 읽어오는데 실패했습니다.');
    return;
end

if size(data, 2) < 2
    error('데이터에 최소 2개의 열(X, Y)이 필요합니다.');
end

fID = fopen(outFile, 'w');
if fID == -1
    error('출력 파일을 생성할 수 없습니다: %s', outFile);
end

% 원래 python 스크립트는 Longitude, Latitude 순서로 CSV에 저장되어 있었음
fprintf(fID, 'Longitude\tLatitude\n');

for i = 1:size(data, 1)
    x = data(i, 1);
    y = data(i, 2);
    
    [lat, lon] = reverse_xy2latlong(x, y);
    
    % Longitude(경도), Latitude(위도) 순으로 데이터 저장
    fprintf(fID, '%.8f\t%.8f\n', lon, lat);
end

fclose(fID);
disp('모든 변환이 완료되었습니다! 🎉');
disp(['저장 완료: ', outFile]);


function [lat, lon] = reverse_xy2latlong(x, y)
    % Lambert Conformal Conic (LCC) 역산 공식
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

    first_xx = 0;
    first_yy = 0;

    rs_x_base = (x - first_xx) * 2000;
    rs_y_base = (y - first_yy) * 2000;

    xn = rs_x_base - XO;
    yn = ro - rs_y_base + YO;

    ra = sqrt(xn^2 + yn^2);
    if sn < 0.0
        ra = -ra;
    end

    alat = (re * sf / ra)^(1.0 / sn);
    alat = 2.0 * atan(alat) - pi * 0.5;

    if abs(xn) <= 0.0
        theta = 0.0;
    else
        if abs(yn) <= 0.0
            theta = pi * 0.5;
            if xn < 0.0
                theta = -theta;
            end
        else
            theta = atan2(xn, yn);
        end
    end

    alon = theta / sn + olon;

    lat = alat / DEGRAD;
    lon = alon / DEGRAD;
end
