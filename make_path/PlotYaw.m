%%%%%%%%%%%% x , y , index, ROI, Yaw

addpath('C:\Users\hsh\Desktop\자율주행\Path_Maker\Path\26_jeju\results\plotSMimage');
path_in = table2array(readtable(['shift_out_jeju.txt']));
path_in_size = length(path_in);

path_in(path_in_size+1, :) = path_in(1, :);

in_yaw = [];
for i = 1:path_in_size
    dist_x = path_in(i+1, 1) - path_in(i, 1);
    dist_y = path_in(i+1, 2) - path_in(i, 2);
    in_yaw(i) = atan2(dist_y, dist_x);
end

path_in(path_in_size+1, :) = [];

% path_in(:,5) = in_yaw;

figure
hold on
plot(1:path_in_size, in_yaw, 'r*')
title("path 241103 in")
% figure
% hold on
% plot(path_in(:,1), path_in(:,2), 'r*')
% axis equal
