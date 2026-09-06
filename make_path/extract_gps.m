% Extract_GPS.m
% ROS 1 bag 파일에서 /ublox1/fix 토픽의 위도/경도 데이터를 추출하여 CSV로 저장하는 스크립트

% 1. 처리할 bag 파일 이름 입력
origBagFileName = 'c:\Users\coros\OneDrive\바탕 화면\자율주행\bag\ublox1_out_2026-03-24-13-52-41.bag'; 
csvFileName = 'c:\Users\coros\OneDrive\바탕 화면\자율주행\bag\gps_data_ublox.csv';

% 파일이 존재하는지 확인
if ~isfile(origBagFileName)
    error(['실패: "', origBagFileName, '" 파일을 찾을 수 없습니다.']);
end

% MATLAB의 rosbag 함수는 한글 경로('바탕 화면', '자율주행')를 지원하지 않으므로 영어(ASCII)로 구성된 임시 폴더로 파일 복사
tempDir = tempdir; % C:\Users\coros\AppData\Local\Temp 처럼 순수 영어 경로
[~, name, ext] = fileparts(origBagFileName);
asciiBagFileName = fullfile(tempDir, [name, ext]);

disp('MATLAB rosbag 한글 경로 인식 오류를 방지하기 위해 임시 폴더로 파일을 복사 중입니다...');
copyfile(origBagFileName, asciiBagFileName);

disp(['1. 복사된 "', asciiBagFileName, '" 파일을 불러오는 중입니다... 잠시만 기다려주세요.']);
try
    bag = rosbag(asciiBagFileName);
catch ME
    delete(asciiBagFileName); % 에러 발생 시 임시 파일 삭제
    rethrow(ME);
end

disp('2. GPS 토픽(/ublox1/fix)을 검색 중입니다...');
bagSelection = select(bag, 'Topic', '/ublox1/fix');

if bagSelection.NumMessages == 0
    delete(asciiBagFileName); % 임시 파일 삭제
    error('실패: 해당 bag 파일 내에 /ublox1/fix 토픽 데이터가 없습니다.');
end

disp(['- 총 ', num2str(bagSelection.NumMessages), '개의 GPS 데이터를 찾았습니다!']);
disp('3. 위도(Latitude)와 경도(Longitude) 데이터를 추출 중입니다...');

% 메시지를 구조체(struct) 형식으로 빠르고 안전하게 읽어옴
msgStructs = readMessages(bagSelection, 'DataFormat', 'struct');

% 위도/경도 배열로 변환
lat = cellfun(@(m) m.Latitude, msgStructs);
lon = cellfun(@(m) m.Longitude, msgStructs);

disp('4. 추출된 데이터를 CSV 파일로 저장하는 중입니다...');
% 데이터를 테이블형식으로 생성
gpsTable = table(lat, lon, 'VariableNames', {'Latitude', 'Longitude'});

% CSV 파일로 원래 폴더에 저장
writetable(gpsTable, csvFileName);

% 임시 파일 삭제
delete(asciiBagFileName);

disp(['완료!! 🎉 GPS 데이터가 "', csvFileName, '" 파일로 성공적으로 저장되었습니다.']);
