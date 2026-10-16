function fig2_ens_compare(results, saveDir)
% FIG2_ENS_COMPARE  失负荷量 & 经济损失对比（5 场景，NaN 安全）

style_poster(); C = poster_colors();
K = numel(results);
shortNames = {'S1','S2','S3','S4','S5'};
longNames  = {results.name};

ens  = [results.ENS];
loss = [results.ENS_w];
succ = [results.success];

% ★ 求解失败场景，置 NaN 占位（画图时显示为空柱）
ens(~succ)  = NaN;
loss(~succ) = NaN;

fig = figure('Position',[50 50 1500 550]);

%% ============ 面板 (a)：ENS & 经济损失 ============
subplot(1,2,1);
h = bar([ens(:), loss(:)/1000], 'grouped');
h(1).FaceColor = [0.30 0.55 0.85];
h(2).FaceColor = [0.85 0.40 0.30];
set(gca,'XTickLabel', shortNames,'FontSize',13);
ylabel('ENS (MWh)  /  损失 (千$)','FontSize',14);
title('失负荷 & 经济损失','FontSize',15);
legend({'ENS (MWh)','经济损失 (千$)'}, 'Location','northeast','FontSize',11);
grid on;

% 标注失败场景
for k = 1:K
    if ~succ(k)
        yl = ylim();
        text(k, yl(2)*0.5, '求解失败', ...
            'HorizontalAlignment','center','FontSize',10, ...
            'Color','r','FontWeight','bold','Rotation',90);
    end
end

%% ============ 面板 (b)：改进幅度 ============
subplot(1,2,2);
if succ(1) && ens(1) > 1e-6   % 放宽阈值，1e-16 判无效，1e-3 判有效
    % 基准 S1 有效 → 正常计算
    impENS  = (ens(1) - ens)  / ens(1)  * 100;
    impLoss = (loss(1) - loss)/ loss(1) * 100;
    impENS(~isfinite(impENS))   = 0;
    impLoss(~isfinite(impLoss)) = 0;

    b = bar([impENS(:), impLoss(:)]);
    b(1).FaceColor = [0.30 0.55 0.85];
    b(2).FaceColor = [0.85 0.40 0.30];
    ylabel('相对 S1 下降 (%)','FontSize',14);
else
    % 基准无效：画 0 柱 + 文字提示
    bar(zeros(K,2));
    text(K/2, 0.5, '基准 S1 无效，无法计算改进幅度', ...
        'HorizontalAlignment','center','FontSize',12,'Color','r', ...
        'BackgroundColor',[1 1 1 0.9], 'Margin', 3);
    ylim([-1 1]);
    ylabel('改进幅度 (%)','FontSize',14);
end
set(gca,'XTickLabel', shortNames,'FontSize',13);
title('改进幅度','FontSize',15);
legend({'物理 ENS','经济损失'},'Location','northwest','FontSize',11);
grid on;

sgtitle('恢复策略的失负荷与经济性对比','FontSize',16,'FontWeight','bold');

exportgraphics(fig, fullfile(saveDir,'fig2_ens_compare.png'), 'Resolution', 300);
fprintf('    → 保存: fig2_ens_compare.png\n');
end