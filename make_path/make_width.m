% 파일 로드 (탭으로 구분된 데이터)
data = readmatrix('C:\Users\suhyeon\Desktop\Path_Maker\Path\4th_SM_UNIV\path_241103_in.txt', 'Delimiter', '\t');

% 도로 중심 좌표 (첫 번째 열: x, 두 번째 열: y)
x_center = data(:,1);
y_center = data(:,2);

% 도로 좌우 폭 설정 (예시: 좌측 2m, 우측 4m)
road_width_left = 1;   % 좌측 차선 폭
road_width_right = 2;  % 우측 차선 폭

% 각 점에서의 법선 벡터 계산
num_points = length(x_center);
x_left = zeros(num_points, 1);
y_left = zeros(num_points, 1);
x_right = zeros(num_points, 1);
y_right = zeros(num_points, 1);

% 첫 번째 점 처리
dx = x_center(2) - x_center(1);
dy = y_center(2) - y_center(1);
norm_factor = sqrt(dx^2 + dy^2);
nx = -dy / norm_factor;
ny = dx / norm_factor;
x_left(1) = x_center(1) + road_width_left * nx;   % 좌측 폭 적용
y_left(1) = y_center(1) + road_width_left * ny;
x_right(1) = x_center(1) - road_width_right * nx; % 우측 폭 적용
y_right(1) = y_center(1) - road_width_right * ny;

for i = 2:num_points-1
    % 중심선의 접선 벡터 계산
    dx = x_center(i+1) - x_center(i-1);
    dy = y_center(i+1) - y_center(i-1);
    
    % 법선 벡터 (90도 회전)
    norm_factor = sqrt(dx^2 + dy^2);
    nx = -dy / norm_factor;
    ny = dx / norm_factor;
    
    % 좌우 경계 좌표 계산
    x_left(i) = x_center(i) + road_width_left * nx;   % 좌측 폭 적용
    y_left(i) = y_center(i) + road_width_left * ny;
    x_right(i) = x_center(i) - road_width_right * nx; % 우측 폭 적용
    y_right(i) = y_center(i) - road_width_right * ny;
end

% 마지막 점 처리
dx = x_center(end) - x_center(end-1);
dy = y_center(end) - y_center(end-1);
norm_factor = sqrt(dx^2 + dy^2);
nx = -dy / norm_factor;
ny = dx / norm_factor;
x_left(end) = x_center(end) + road_width_left * nx;   % 좌측 폭 적용
y_left(end) = y_center(end) + road_width_left * ny;
x_right(end) = x_center(end) - road_width_right * nx; % 우측 폭 적용
y_right(end) = y_center(end) - road_width_right * ny;

% 결과 저장 (동일한 부분 생략)
