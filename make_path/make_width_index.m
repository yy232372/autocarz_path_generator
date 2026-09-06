% 파일 로드 (탭으로 구분된 데이터)
data = readmatrix('yeah_fin_v3.txt', 'Delimiter', '\t');

% 도로 중심 좌표 (첫 번째 열: x, 두 번째 열: y)
x_center = data(:,1);
y_center = data(:,2);

% 도로 폭 설정 (구간별 설정)
num_points = length(x_center);
road_width_left = ones(num_points, 1) * 0.001;   % 기본 좌측 폭: 2m
road_width_right = ones(num_points, 1) * 2.0; % 기본 우측 폭: 3m

% 특정 인덱스 구간에 대해 다른 폭 적용
% road_width_left(1954:1997) = 0.2;   % 예: 인덱스 50~100 구간에서 좌측 폭을 4m로 설정
% road_width_right(1954:1997) = 2.8; % 예: 인덱스 150~200 구간에서 우측 폭을 5m로 설정
% 
% road_width_left(2131:2184) = 0.2;   
% road_width_right(2131:2184) = 2.8;

% 각 점에서의 법선 벡터 계산
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
x_left(1) = x_center(1) + road_width_left(1) * nx;
y_left(1) = y_center(1) + road_width_left(1) * ny;
x_right(1) = x_center(1) - road_width_right(1) * nx;
y_right(1) = y_center(1) - road_width_right(1) * ny;

% 중간 점 처리
for i = 2:num_points-1
    dx = x_center(i+1) - x_center(i-1);
    dy = y_center(i+1) - y_center(i-1);
    norm_factor = sqrt(dx^2 + dy^2);
    nx = -dy / norm_factor;
    ny = dx / norm_factor;
    x_left(i) = x_center(i) + road_width_left(i) * nx;
    y_left(i) = y_center(i) + road_width_left(i) * ny;
    x_right(i) = x_center(i) - road_width_right(i) * nx;
    y_right(i) = y_center(i) - road_width_right(i) * ny;
end

% 마지막 점 처리
dx = x_center(end) - x_center(end-1);
dy = y_center(end) - y_center(end-1);
norm_factor = sqrt(dx^2 + dy^2);
nx = -dy / norm_factor;
ny = dx / norm_factor;
x_left(end) = x_center(end) + road_width_left(end) * nx;
y_left(end) = y_center(end) + road_width_left(end) * ny;
x_right(end) = x_center(end) - road_width_right(end) * nx;
y_right(end) = y_center(end) - road_width_right(end) * ny;

% 결과 저장
output_left = [x_left, y_left];
output_right = [x_right, y_right];
writematrix(output_left, 'yeah_left2.txt', 'Delimiter', '\t');
writematrix(output_right, 'yeah_right2.txt', 'Delimiter', '\t');

% 시각화
figure;
plot(x_center, y_center, 'k-', 'LineWidth', 1.5); hold on;
plot(x_left, y_left, 'r-', 'LineWidth', 1);
plot(x_right, y_right, 'b-', 'LineWidth', 1);
legend('Center Line', 'Left Edge', 'Right Edge');
xlabel('X Coordinate'); ylabel('Y Coordinate');
title('Road Edges with Variable Widths');
grid on;
axis equal;
