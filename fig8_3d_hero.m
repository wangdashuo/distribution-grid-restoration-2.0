function fig8_3d_hero(sys, testFault, saveDir)
% FIG8_3D_HERO  3D 立体渲染主视觉图
%   节点悬浮在浅色城市天际线剪影上
%   普通馈线浅灰细线 / 故障线红色粗线 / 联络开关橙色虚线
%   数据中心紫色 / 医院红色十字 / 变电站绿色
%
% 用法:
%   fig8_3d_hero(sys, testFault, 'presentation/output')

    if nargin < 3, saveDir = '.'; end
    if ~exist(saveDir, 'dir'), mkdir(saveDir); end

    style_poster();

    %% ===== 1. 坐标归一化 =====
    switch sys.nNode
        case 69, xy = layout_ieee69();
        case 33, xy = layout_ieee33();
        otherwise, error('无 %d 节点布局', sys.nNode);
    end
    % 映射到 [0,14] × [-3.2, 3.2]
    xy_n = zeros(size(xy));
    xy_n(:,1) = (xy(:,1) - min(xy(:,1))) / max(diff(minmax(xy(:,1))),1e-6) * 14;
    xy_n(:,2) = (xy(:,2) - mean(xy(:,2))) / max(range2(xy(:,2)),1e-6) * 6.4;

    %% ===== 2. 高度层参数 =====
    zCityBase = 0.00;
    zLine     = 0.90;
    zNode     = 1.15;
    zCritical = 1.55;

    %% ===== 3. 城市天际线剪影 =====
    fig = figure('Name','3D Hero','Color','w', ...
                 'Units','pixels','Position',[60 60 1500 780]);
    ax = axes('Parent', fig);
    hold(ax, 'on');

    % --- 3.1 底图（浅米色不规则轮廓）---
    th = linspace(0, 2*pi, 60);
    rBase = 1 + 0.10*sin(5*th) + 0.06*cos(7*th + 1.2);
    cx = 7;  cy = 0;
    baseX = cx + 8.6 * rBase .* cos(th);
    baseY = cy + 3.6 * rBase .* sin(th);
    fill3(ax, baseX, baseY, zCityBase*ones(size(th)), ...
          [0.975 0.965 0.945], 'EdgeColor', [0.88 0.87 0.86], ...
          'LineWidth', 0.8, 'FaceAlpha', 0.98);

    % --- 3.2 一层淡色阴影带（模拟城市区块）---
    nRegion = 4;
    regionCols = [0.94 0.93 0.91;  0.92 0.94 0.96;
                  0.95 0.93 0.92;  0.93 0.95 0.92];
    rng(11);
    for r = 1:nRegion
        px = cx + (rand-0.5)*10;
        py = cy + (rand-0.5)*4;
        rx = 2.5 + 1.8*rand;
        ry = 1.2 + 0.8*rand;
        ang = 2*pi*rand;
        ellTh = linspace(0,2*pi,40);
        ex = px + rx*cos(ellTh)*cos(ang) - ry*sin(ellTh)*sin(ang);
        ey = py + rx*cos(ellTh)*sin(ang) + ry*sin(ellTh)*cos(ang);
        fill3(ax, ex, ey, (zCityBase+0.005)*ones(size(ex)), ...
              regionCols(r,:), 'EdgeColor', 'none', 'FaceAlpha', 0.7);
    end

    % --- 3.3 楼群（程序化生成，低饱和浅灰蓝）---
    rng(3);
    nBld = 130;
    bldColor = [0.80 0.84 0.89];
    bldEdge  = [0.70 0.74 0.80];
    for i = 1:nBld
        p = 2*rand - 1;  q = 2*rand - 1;
        if p^2 + q^2 > 0.88, continue; end
        bx = cx + 8.2 * p;
        by = cy + 3.3 * q;
        bw = 0.14 + 0.10*rand;
        bd = 0.14 + 0.10*rand;
        bh = 0.10 + 0.55 * rand^1.8;       % 大部分矮、少数尖
        % 楼的颜色稍微随机化（很轻微）
        c = bldColor + 0.06*(rand-0.5);
        drawBox(ax, bx, by, zCityBase, bw, bd, bh, c, bldEdge);
    end

    %% ===== 4. 拓扑线路 =====
    % --- 4.1 普通馈线 ---
    for e = 1:sys.nBranch
        if sys.isTie(e) || testFault(e), continue; end
        x1 = xy_n(sys.from(e),1); y1 = xy_n(sys.from(e),2);
        x2 = xy_n(sys.to(e),  1); y2 = xy_n(sys.to(e),  2);
        plot3(ax, [x1 x2], [y1 y2], [zLine zLine], '-', ...
              'Color', [0.72 0.72 0.72], 'LineWidth', 1.0);
    end

    % --- 4.2 联络开关（橙色虚线）---
    for e = find(sys.isTie)'
        x1 = xy_n(sys.from(e),1); y1 = xy_n(sys.from(e),2);
        x2 = xy_n(sys.to(e),  1); y2 = xy_n(sys.to(e),  2);
        plot3(ax, [x1 x2], [y1 y2], [zLine zLine], '--', ...
              'Color', [0.94 0.58 0.14], 'LineWidth', 2.4);
    end

    % --- 4.3 故障线路（红色粗线）---
    for e = find(testFault)'
        x1 = xy_n(sys.from(e),1); y1 = xy_n(sys.from(e),2);
        x2 = xy_n(sys.to(e),  1); y2 = xy_n(sys.to(e),  2);
        plot3(ax, [x1 x2], [y1 y2], [zLine zLine], '-', ...
              'Color', [0.86 0.18 0.20], 'LineWidth', 4.6);
    end

    %% ===== 5. 节点（悬浮）=====
    Pmax = max(sys.Pload_kW);  if Pmax <= 0, Pmax = 1; end

    for j = 1:sys.nNode
        x = xy_n(j,1);  y = xy_n(j,2);

        if j == sys.root
            % 变电站：绿色方块
            plot3(ax, x, y, zNode, 's', ...
                  'MarkerSize', 18, ...
                  'MarkerFaceColor', [0.20 0.72 0.32], ...
                  'MarkerEdgeColor', [0.10 0.35 0.15], ...
                  'LineWidth', 1.6);
        elseif strcmp(sys.nodeType{j}, '数据中心')
            % 数据中心：紫色大五角
            plot3(ax, x, y, zCritical, 'p', ...
                  'MarkerSize', 40, ...
                  'MarkerFaceColor', [0.60 0.32 0.85], ...
                  'MarkerEdgeColor', [0.35 0.10 0.55], ...
                  'LineWidth', 2.0);
            % 悬浮柱线
            plot3(ax, [x x], [y y], [zLine zCritical], ':', ...
                  'Color', [0.60 0.32 0.85], 'LineWidth', 1.0);
        elseif strcmp(sys.nodeType{j}, '医院')
            % 医院：红色六芒星（近似十字）
            plot3(ax, x, y, zCritical, 'h', ...
                  'MarkerSize', 34, ...
                  'MarkerFaceColor', [0.92 0.22 0.24], ...
                  'MarkerEdgeColor', [0.55 0.08 0.10], ...
                  'LineWidth', 2.0);
            plot3(ax, [x x], [y y], [zLine zCritical], ':', ...
                  'Color', [0.92 0.22 0.24], 'LineWidth', 1.0);
        else
            sz = 10 + 14*(sys.Pload_kW(j)/Pmax)^0.5;
            plot3(ax, x, y, zNode, 'o', ...
                  'MarkerSize', sz, ...
                  'MarkerFaceColor', [0.55 0.75 0.98], ...
                  'MarkerEdgeColor', [0.15 0.30 0.55], ...
                  'LineWidth', 0.8);
        end
    end

    %% ===== 6. 关键节点文字标注（不堆字）=====
    dcList  = find(strcmp(sys.nodeType, '数据中心'));
    hosList = find(strcmp(sys.nodeType, '医院'));
    for j = dcList'
        text(ax, xy_n(j,1)+0.35, xy_n(j,2)+0.35, zCritical+0.15, ...
             sprintf('DC@%d', j), ...
             'FontSize', 11, 'FontWeight','bold', ...
             'Color', [0.45 0.15 0.65], ...
             'BackgroundColor', [1 1 1 0.75], 'Margin', 1.5);
    end
    for j = hosList'
        text(ax, xy_n(j,1)+0.35, xy_n(j,2)-0.45, zCritical+0.15, ...
             sprintf('H@%d', j), ...
             'FontSize', 11, 'FontWeight','bold', ...
             'Color', [0.75 0.10 0.15], ...
             'BackgroundColor', [1 1 1 0.75], 'Margin', 1.5);
    end
    text(ax, xy_n(sys.root,1)-0.9, xy_n(sys.root,2)+0.6, zNode+0.3, ...
         '变电站', 'FontSize', 11, 'FontWeight','bold', ...
         'Color', [0.10 0.45 0.20], ...
         'BackgroundColor', [1 1 1 0.75], 'Margin', 1.5);

    %% ===== 7. 视角与外观 =====
    view(ax, -42, 26);
    axis(ax, 'off');
    xlim(ax, [min(xy_n(:,1))-1.5, max(xy_n(:,1))+1.5]);
    ylim(ax, [min(xy_n(:,2))-1.5, max(xy_n(:,2))+1.5]);
    zlim(ax, [-0.30, 2.20]);
    pbaspect(ax, [14 6.6 2.8]);

    % 轻微光照
    camlight(ax, 'headlight');
    lighting(ax, 'gouraud');

    % 白背景
    set(ax, 'Color', 'w', 'FontName', 'Microsoft YaHei');

    %% ===== 8. 简图例（右上角）=====
    lgd = legend(ax, ...
        [ plot3(ax, nan,nan,nan,'-','Color',[0.72 0.72 0.72],'LineWidth',1.4), ...
          plot3(ax, nan,nan,nan,'-','Color',[0.86 0.18 0.20],'LineWidth',4.0), ...
          plot3(ax, nan,nan,nan,'--','Color',[0.94 0.58 0.14],'LineWidth',2.4), ...
          plot3(ax, nan,nan,nan,'p','MarkerSize',16, ...
                'MarkerFaceColor',[0.60 0.32 0.85],'MarkerEdgeColor','k','LineStyle','none'), ...
          plot3(ax, nan,nan,nan,'h','MarkerSize',15, ...
                'MarkerFaceColor',[0.92 0.22 0.24],'MarkerEdgeColor','k','LineStyle','none'), ...
          plot3(ax, nan,nan,nan,'s','MarkerSize',14, ...
                'MarkerFaceColor',[0.20 0.72 0.32],'MarkerEdgeColor','k','LineStyle','none') ], ...
        {'馈线','故障线路','联络开关','数据中心','医院','变电站'}, ...
        'Location', 'northeastoutside', 'FontSize', 11, 'Box', 'off');

    %% ===== 9. 保存 =====
    if ~isempty(saveDir)
        outFile = fullfile(saveDir, 'fig8_3d_hero.png');
        exportgraphics(fig, outFile, 'Resolution', 300);
        fprintf('    → 保存: fig8_3d_hero.png\n');
    end
end

%% ================= 局部函数 =================
function drawBox(ax, x, y, z, w, d, h, faceColor, edgeColor)
% 画一个 3D 长方体（6 个面）
    V = [x-w/2, y-d/2, z;
         x+w/2, y-d/2, z;
         x+w/2, y+d/2, z;
         x-w/2, y+d/2, z;
         x-w/2, y-d/2, z+h;
         x+w/2, y-d/2, z+h;
         x+w/2, y+d/2, z+h;
         x-w/2, y+d/2, z+h];
    F = [1 2 3 4;
         5 6 7 8;
         1 2 6 5;
         2 3 7 6;
         3 4 8 7;
         4 1 5 8];
    patch(ax, 'Vertices', V, 'Faces', F, ...
          'FaceColor', faceColor, 'EdgeColor', edgeColor, ...
          'LineWidth', 0.4, 'FaceAlpha', 1.0);
end

function r = range2(v)
    r = max(v) - min(v);
end